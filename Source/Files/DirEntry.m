//
//  DirEntry.m
//  Crossbow
//
// Copyright (C) 2009 Roland Rabien
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


#import "DirEntry.h"
#import "Util.h"
#import "NSImageAdditions.h"
#import "Preferences.h"
#import "FileAccess.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSMutableDictionary* dirEntryCache = nil;
NSArray* imageTypes = nil;

// Thumbnail cache files are keyed archives of plain Foundation collections; the
// cache predates secure coding, so it is read and written without it.
static BOOL writeArchive(id object, NSString* path)
{
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:nil];
    return data && [data writeToFile:path atomically:YES];
}

// Builds a thumbnail with ImageIO. When the file carries an embedded preview,
// as camera JPEGs do, only the header is read instead of the whole image,
// which is what makes browsing a network share bearable. Orientation is applied.
static NSImage* thumbnailWithImageIO(NSURL* url)
{
    NSDictionary* srcOpts = @{(id)kCGImageSourceShouldCache: @NO};
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)url, (__bridge CFDictionaryRef)srcOpts);
    if (!src)
        return nil;

    NSMutableDictionary* opts = [@{(id)kCGImageSourceCreateThumbnailFromImageIfAbsent: @YES,
                                   (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                                   (id)kCGImageSourceThumbnailMaxPixelSize: @256} mutableCopy];
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef)opts);

    // An embedded preview smaller than the cell is not worth keeping; decode instead
    if (cg && MAX(CGImageGetWidth(cg), CGImageGetHeight(cg)) < 128)
    {
        CGImageRelease(cg);
        [opts removeObjectForKey:(id)kCGImageSourceCreateThumbnailFromImageIfAbsent];
        [opts setObject:@YES forKey:(id)kCGImageSourceCreateThumbnailFromImageAlways];
        cg = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef)opts);
    }
    CFRelease(src);
    if (!cg)
        return nil;

    NSImage* image = [[NSImage alloc] initWithCGImage:cg size:NSZeroSize];
    CGImageRelease(cg);
    return image;
}

static id readArchive(NSString* path)
{
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (!data)
        return nil;
    NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
    if (!unarchiver)
        return nil;
    [unarchiver setRequiresSecureCoding:NO];
    id object = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    return object;
}

@implementation DirEntry

+ (DirEntry*)dirEntryWithURL:(NSURL*)url_
{
    if (!dirEntryCache)
    {
        dirEntryCache = [[NSMutableDictionary alloc] initWithCapacity: 1000];

        NSString* thumbDir = [DirEntry thumbnailDir];
        if (![[NSFileManager defaultManager] fileExistsAtPath:thumbDir])
        {
            NSError* err;
            [[NSFileManager defaultManager] createDirectoryAtPath:thumbDir withIntermediateDirectories:YES attributes:nil error:&err];
        }
    }

    DirEntry* de = nil;
    @synchronized (dirEntryCache)
    {
        de = [[dirEntryCache objectForKey:[url_ path]] nonretainedObjectValue];
    }
    if (!de)
    {
        de = [[DirEntry alloc] initWithURL: url_];
        if (de)
        {
            @synchronized (dirEntryCache)
            {
                [dirEntryCache setObject:[NSValue valueWithNonretainedObject:de] forKey:[url_ path]];
            }
        }
        return de;
    }

    [de refresh];
    return [de isInvalid] ? nil : de;
}

// The keys a directory listing fetches for every entry in one go, so that no
// per file calls are needed afterwards. On a network share each of those calls
// is a round trip.
+ (NSArray*)listingKeys
{
    return @[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey, NSURLIsVolumeKey, NSURLContentTypeKey,
             NSURLContentModificationDateKey, NSURLCreationDateKey, NSURLFileSizeKey, NSURLLocalizedNameKey];
}

+ (DirEntry*)dirEntryWithURL:(NSURL*)url_ properties:(NSDictionary*)properties
{
    if (!dirEntryCache)
        [DirEntry dirEntryWithPath:@"/"];    // sets the cache up

    DirEntry* de = nil;
    @synchronized (dirEntryCache)
    {
        de = [[dirEntryCache objectForKey:[url_ path]] nonretainedObjectValue];
    }
    if (!de)
    {
        de = [[DirEntry alloc] init];
        de->url = [url_ copy];
        de->subFolders = MAYBE;
        @synchronized (dirEntryCache)
        {
            [dirEntryCache setObject:[NSValue valueWithNonretainedObject:de] forKey:[url_ path]];
        }
    }
    [de applyProperties:properties];
    return de;
}

- (void)applyProperties:(NSDictionary*)properties
{
    UTType* type = [properties objectForKey:NSURLContentTypeKey];
    @synchronized (self)
    {
        folder           = [[properties objectForKey:NSURLIsDirectoryKey] boolValue];
        link             = [[properties objectForKey:NSURLIsSymbolicLinkKey] boolValue];
        fileType         = [type identifier];
        image            = !folder && fileType && [[DirEntry imageUTIs] containsObject:fileType];
        displayName      = [properties objectForKey:NSURLLocalizedNameKey] ?: [[url path] lastPathComponent];
        creationDate     = [properties objectForKey:NSURLCreationDateKey];
        modificationDate = [properties objectForKey:NSURLContentModificationDateKey];
        fileSize         = folder ? 0 : [[properties objectForKey:NSURLFileSizeKey] longLongValue];
        invalid          = NO;
    }
}

+ (DirEntry*)dirEntryWithPath:(NSString*)path
{
    return [DirEntry dirEntryWithURL: [NSURL fileURLWithPath: path]];
}

- (id)initWithURL:(NSURL*)url_
{
    if (self = [self init])
    {
        url = [url_ copy];

        NSFileManager* fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath: [url path] isDirectory: &folder])
        {
            [self refresh];
            subFolders = MAYBE;
            invalid    = NO;
        }
        else
        {
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{

    [dirEntryCache removeObjectForKey: [url path]];


}

- (NSString*)description
{
    return [url path];
}

- (BOOL)isEqual:(id)anObject
{
    if (anObject == self)
        return YES;
    if (![anObject isKindOfClass:[DirEntry class]])
        return NO;

    return [[url path] isEqual:[[(DirEntry*)anObject url] path]];
}

- (NSUInteger)hash
{
    return [[url path] hash];
}

+ (NSString*)thumbnailDir
{
    return [NSString stringWithFormat: @"%@/Library/Caches/Crossbow/Thumbnails", NSHomeDirectory()];
}

+ (void)clearAllThumbnails
{
    NSFileManager* fm = [NSFileManager defaultManager];

    NSArray* thumbs = [fm contentsOfDirectoryAtPath:[DirEntry thumbnailDir] error:nil];

    for (NSString* filename in thumbs)
    {
        NSString* path = [[DirEntry thumbnailDir] stringByAppendingPathComponent:filename];
        [fm removeItemAtPath:path error:nil];
    }
}

- (NSURL*)url
{
    return url;
}

- (NSString*)path
{
    return [url path];
}

- (NSString*)filename
{
    return [[self path] lastPathComponent];
}

- (NSString*)filetype
{
    NSString* type = nil;
    @synchronized (self)
    {
        type = fileType;
    }
    if (!type)
    {
        type = fileUTI([self path]);
        @synchronized (self)
        {
            fileType = type;
        }
    }
    return type;
}

- (NSString*)filetypeDescription
{
    NSString* uti = [self filetype];
    NSString* desc = uti ? [[UTType typeWithIdentifier:uti] localizedDescription] : nil;
    return desc ? desc : uti;
}

- (void)refresh
{
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath: [url path] isDirectory: &folder])
    {
        fileType = folder ? nil : fileUTI([self path]);
        image = fileType && [[DirEntry imageUTIs] containsObject:fileType];

        NSError* err;
        NSDictionary* attr = [fm attributesOfItemAtPath: [url path] error: &err];

        @synchronized (self)
        {
            displayName = [fm displayNameAtPath: [url path]];


            creationDate       = [attr objectForKey: NSFileCreationDate];
            modificationDate   = [attr objectForKey: NSFileModificationDate];
            fileSize           = folder ? 0 : [[attr objectForKey: NSFileSize] longLongValue];
            link               = [[attr valueForKey:NSFileType] isEqual:NSFileTypeSymbolicLink];
            invalid            = NO;
        }
    }
    else
    {
        invalid = YES;
    }
}

- (NSImage*)icon
{
    return [[NSWorkspace sharedWorkspace] iconForFile: [self path]];
}

- (NSImage*)image
{
    NSImage* img = [[NSImage alloc] initByReferencingURL: [self url]];
    [img setCacheMode:NSImageCacheNever];
    return img;
}

- (NSString*)thumbnailPath
{
    return [NSString stringWithFormat: @"%@/%@.thm", [DirEntry thumbnailDir], md5([self path])];
}

- (BOOL)hasThumbnail
{
    NSFileManager* fm = [NSFileManager defaultManager];

    NSString* thumb = [self thumbnailPath];
    if ([fm fileExistsAtPath:thumb])
    {
        NSDate* fileDate = [self modified];
        if (!fileDate)
        {
            NSDictionary* fileAttr = [fm attributesOfItemAtPath:[self path] error:nil];
            fileDate = [fileAttr objectForKey: NSFileModificationDate];
        }

        NSDictionary* thumAttr = [fm attributesOfItemAtPath:[self thumbnailPath] error:nil];
        NSDate* thumDate = [thumAttr objectForKey: NSFileModificationDate];

        // The thumbnail is stamped with the image's modification time, but that
        // write truncates to microseconds while the image may carry nanoseconds,
        // so an exact comparison sees the image as forever newer. A second of
        // slack is plenty to tell a real edit from rounding.
        if ([fileDate timeIntervalSinceDate:thumDate] > 1.0)
            return NO;

        return YES;
    }
    return NO;
}

- (NSImage*)createThumbnail
{
    NSString* thumbPath = [self thumbnailPath];
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:thumbPath])
        [fm removeItemAtPath:thumbPath error:nil];

    NSImage* thum;
    if (folder)
    {
        thum = [self icon];
        thum = [thum imageByScalingProportionallyToSize: NSMakeSize(128, 128)];
    }
    else
    {
        thum = thumbnailWithImageIO(url);
        if (!thum)
        {
            // Not something ImageIO reads (PDF for one): decode it the slow way
            NSImage* orig = [[NSImage alloc] initByReferencingURL: url];
            if (!orig)
                return nil;

            BOOL pdf = [[self filetype] isEqual:@"com.adobe.pdf"];
            thum = [orig imageByScalingProportionallyToSize: NSMakeSize(128, 128) background: pdf ? [NSColor whiteColor] : [NSColor clearColor] ];
        }
    }

    if (thum)
    {
        NSBitmapImageRep *bits = [NSBitmapImageRep imageRepWithData: [thum TIFFRepresentation]];

        NSData *data = [bits representationUsingType: NSBitmapImageFileTypePNG properties: [NSDictionary dictionary]];

        NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:data, @"thumbnail", [self path], @"path", [self metadata], @"imagemetadata", nil];

        writeArchive(dict, thumbPath);

        NSDictionary* newAttr = [NSDictionary dictionaryWithObjectsAndKeys:[self created], NSFileCreationDate, [self modified], NSFileModificationDate, nil];
        [fm setAttributes:newAttr ofItemAtPath:thumbPath error:nil];
    }
    return thum;
}

- (NSImage*)thumbnail
{
    if (![self hasThumbnail])
        return [self createThumbnail];

    NSDictionary* dict = readArchive([self thumbnailPath]);
    if (dict)
        return [[NSImage alloc] initWithData: [dict objectForKey:@"thumbnail"]];
    else
        return nil;
}

- (NSDictionary*)metadata
{
    if ([self hasThumbnail])
    {
        NSDictionary* dict = readArchive([self thumbnailPath]);
        return [dict objectForKey:@"imagemetadata"];
    }
    else
    {
        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:2];

        if (![self modified])
            [self refresh];

        NSMutableDictionary* file = [NSMutableDictionary dictionaryWithCapacity:10];
        [file setObject:[self displayName] forKey:@"Name"];
        [file setObject:[[self path] stringByDeletingLastPathComponent] forKey: @"Path"];
        [file setObject:stringFromFileSize([self size]) forKey:@"Size"];
        [file setObject:[self modified] forKey:@"Date Modified"];
        [file setObject:[self created] forKey:@"Date Created"];

        [dict setObject:file forKey:@"{File}"];

        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);

        if (source)
        {
            NSDictionary* properties = (NSDictionary*)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));

            [dict addEntriesFromDictionary:properties];

            CFRelease(source);
        }
        return [NSDictionary dictionaryWithDictionary:dict];
    }
}

- (int)rotationAngle
{
    NSDictionary* metadata = [self metadata];
    if (!metadata) return 0;

    NSNumber* rot = [metadata objectForKey:(NSString*)kCGImagePropertyOrientation];
    if (!rot) return 0;

    if ([rot intValue] == 3)
        return 180;
    else if ([rot intValue] == 8)
        return 90;
    else if ([rot intValue] == 6)
        return 270;

    return 0;
}

- (NSDate*)created
{
    NSDate* res = nil;
    @synchronized (self)
    {
        res = creationDate;
    }
    return res;
}

- (NSDate*)modified
{
    NSDate* res = nil;
    @synchronized (self)
    {
        res = modificationDate;
    }
    return res;
}

- (long long)size
{
    return fileSize;
}

+ (NSArray*)imageUTIs
{
    if (!imageTypes)
        imageTypes = [[NSImage imageTypes] copy];

    return imageTypes;
}

- (BOOL)isInvalid
{
    return invalid;
}

- (BOOL)isFolder
{
    return folder;
}

- (BOOL)isFile
{
    return !folder;
}

- (BOOL)isLink
{
    return link;
}

- (BOOL)isImage
{
    return image;
}

- (BOOL)isFilesystemRoot
{
    NSArray* roots = [DirEntry getRootItems];
    return [roots containsObject: self];
}

- (BOOL)isChildOf:(DirEntry*)de
{
    DirEntry* parent = [self getParent];
    while (parent)
    {
        if ([parent isEqual:de])
            return YES;
        parent = [parent getParent];
    }
    return NO;
}

- (int)hasSubFolders:(BOOL)allowMaybe
{
    if (!folder)
        return NO;
    if (allowMaybe || subFolders != MAYBE)
        return subFolders;

    // One shallow listing with the directory flag prefetched
    NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                         options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    subFolders = NO;
    for (NSURL* item in contents)
    {
        NSNumber* isDir = nil;
        if ([item getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil] && [isDir boolValue])
        {
            subFolders = YES;
            break;
        }
    }
    return subFolders;
}

- (NSString*)displayName
{
    NSString* res = nil;
    @synchronized (self)
    {
        res = displayName;
    }
    return res;
}

- (DirEntry*)getLinkedDirEntry
{
    if (link)
        return [DirEntry dirEntryWithPath: expandIfLink([url path])];
    else
        return self;
}

- (DirEntry*)getParent
{
    if ([self isFilesystemRoot])
        return nil;
    else
        return [DirEntry dirEntryWithPath: [[self path] stringByDeletingLastPathComponent]];
}

- (NSArray*)getHierarchy
{
    NSMutableArray* res = [NSMutableArray arrayWithCapacity:10];

    DirEntry* de = self;
    if (de.isFilesystemRoot)
    {
        return [NSArray arrayWithObject:de];
    }
    else
    {
        while (de)
        {
            [res insertObject:de atIndex:0];
            de = [de getParent];
        }
    }
    return res;
}

// Lists the folder with every attribute the entries need fetched in the same
// call, so a folder costs a couple of round trips rather than several per file.
- (NSArray*)listContents:(BOOL)foldersOnly
{
    NSArray* keys = [DirEntry listingKeys];
    NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:keys
                                                                         options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray* res = [NSMutableArray arrayWithCapacity:[contents count]];
    for (NSURL* item in contents)
    {
        NSDictionary* props = [item resourceValuesForKeys:keys error:nil];   // already fetched, no I/O
        DirEntry* de = nil;

        if ([[props objectForKey:NSURLIsSymbolicLinkKey] boolValue])
        {
            // Links are rare: resolve them the thorough way so a link to a folder behaves as one
            if (isVisiblePath([item path]))
                de = [DirEntry dirEntryWithPath:[item path]];
        }
        else if (![[props objectForKey:NSURLIsVolumeKey] boolValue] && ![[item path] isEqualToString:@"/dev"])
        {
            de = [DirEntry dirEntryWithURL:item properties:props];
        }

        if (de && (foldersOnly ? [de isFolder] : ([de isFolder] || [de isImage])))
            [res addObject:de];
    }
    return res;
}

- (NSArray*)getSubItems
{
    if (!folder)
        return nil;

    NSArray* res = [self listContents:NO];
    BOOL sawSubFolders = NO;
    for (DirEntry* de in res)
        if ([de isFolder])
            sawSubFolders = YES;
    subFolders = sawSubFolders;
    return [NSArray arrayWithArray:res];
}

- (NSArray*)deepGetSubItems
{
    if (!folder)
        return nil;

    NSMutableArray* res = [NSMutableArray arrayWithCapacity:10];

    NSArray* items = [self getSubItems];
    for (DirEntry* de in items)
    {
        [res addObject:de];
        if ([de isFolder])
            [res addObjectsFromArray: [de deepGetSubItems]];
    }

    return res;
}

- (NSArray*)getSubFiles
{
    BOOL sawSubFolder = NO;
    NSMutableArray* res = [NSMutableArray arrayWithCapacity: 10];
    for (DirEntry* de in [self getSubItems])
    {
        if (de && [de isFile])
            [res addObject: de];
        if (de && [de isFolder])
            sawSubFolder = YES;
    }
    subFolders = sawSubFolder;
    return [NSArray arrayWithArray: res];
}

- (NSArray*)getSubFolders
{
    if (!folder)
        return nil;

    NSArray* res = [self listContents:YES];
    subFolders = [res count] > 0;
    return [NSArray arrayWithArray:res];
}

+ (NSArray*)getRootItems
{
    NSArray* volumes = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:nil options:NSVolumeEnumerationSkipHiddenVolumes];
    NSMutableArray* roots = [NSMutableArray arrayWithCapacity:[volumes count]];
    for (NSURL* url in volumes)
        [roots addObject:[url path]];

    NSMutableArray* res = [NSMutableArray arrayWithCapacity: [roots count]];
    for (NSString* path in roots)
    {
        if (![path isEqual:@"/home"] && ![path isEqual:@"/net"])
        {
            DirEntry* de = [DirEntry dirEntryWithPath: path];
            if (de)
                [res addObject: de];
        }
    }
    return [NSArray arrayWithArray: res];
}

+ (NSArray*)getUserRootItems
{
    NSMutableArray* roots = [NSMutableArray array];
    for (NSString* path in prefsGet(PrefRootPaths))
    {
        DirEntry* de = [DirEntry dirEntryWithPath:path];
        if (de && ![de isInvalid])
            [roots addObject:de];
    }
    return roots;
}

+ (NSArray*)getDisplayRootItems
{
#ifdef APPSTORE
    return [DirEntry getUserRootItems];
#else
    // The folders the user added first, then every mounted volume
    NSMutableArray* roots = [[DirEntry getUserRootItems] mutableCopy];
    for (DirEntry* de in [DirEntry getRootItems])
        if (![roots containsObject:de])
            [roots addObject:de];
    return roots;
#endif
}

+ (void)moveDisplayRootItems:(NSArray*)moved toIndex:(NSInteger)index
{
    NSMutableArray* paths = [prefsGet(PrefRootPaths) mutableCopy];
    if (!paths)
        paths = [NSMutableArray array];

    index = MIN(MAX(index, 0), (NSInteger)[paths count]);
    for (NSString* path in moved)
    {
        NSUInteger i = [paths indexOfObject:path];
        if (i != NSNotFound)
        {
            [paths removeObjectAtIndex:i];
            if ((NSInteger)i < index)
                index--;
        }
    }
    [paths insertObjects:moved atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, [moved count])]];

    prefsSet(PrefRootPaths, paths);
}

+ (void)addDisplayRootItem:(NSString*)path
{
    NSMutableArray* paths = [prefsGet(PrefRootPaths) mutableCopy];
    if (!paths)
        paths = [NSMutableArray array];

    [paths addObject:path];

    prefsSet(PrefRootPaths, paths);

    [[FileAccess sharedManager] saveAccessTo:path];
}

+ (void)removeDisplayRootItem:(NSString*)path
{
    NSMutableArray* paths = [prefsGet(PrefRootPaths) mutableCopy];
    if (!paths)
        paths = [NSMutableArray array];

    [paths removeObject:path];

    prefsSet(PrefRootPaths, paths);
}

+ (DirEntry*)getDesktop
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSAllDomainsMask, YES);
    if ([paths count] > 0)
        return [DirEntry dirEntryWithPath: [paths objectAtIndex: 0]];
    else
        return nil;
}

+ (DirEntry*)getHome
{
    return [DirEntry dirEntryWithPath: NSHomeDirectory()];
}

+ (DirEntry*)getDocuments
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSAllDomainsMask, YES);
    if ([paths count] > 0)
        return [DirEntry dirEntryWithPath: [paths objectAtIndex: 0]];
    else
        return nil;
}

+ (DirEntry*)getDownloads
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSAllDomainsMask, YES);
    if ([paths count] > 0)
        return [DirEntry dirEntryWithPath: [paths objectAtIndex: 0]];
    else
        return nil;
}

@end
