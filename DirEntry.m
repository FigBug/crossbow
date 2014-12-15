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

NSMutableDictionary* dirEntryCache = nil;
NSArray* imageTypes = nil;

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
	
	NSValue* dew = [dirEntryCache objectForKey: [url_ path]];
	if (!dew)
	{
		DirEntry* de = [[DirEntry alloc] initWithURL: url_];
		if (de)
		{
			dew = [NSValue valueWithNonretainedObject: de];
			[dirEntryCache setObject:dew forKey:[url_ path]];
            return de;
		}
		else
		{
			return nil;
		}
	}
	else
	{
		DirEntry* de = [dew nonretainedObjectValue];
		[de refresh];
		if ([de isInvalid])
			return nil;
	}
	return [dew nonretainedObjectValue];
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
	NSString* s1 = [url path];
	NSString* s2 = [[anObject url] path];
	
	return [s1 isEqual: s2];
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
	NSError* error;
	return [[NSWorkspace sharedWorkspace] typeOfFile:[self path] error: &error];
}

- (NSString*)filetypeDescription
{
	return [[NSWorkspace sharedWorkspace] localizedDescriptionForType: [self filetype]];
}

- (void)refresh
{
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath: [url path] isDirectory: &folder])
	{
		if (!folder)
			image = [[DirEntry imageUTIs] containsObject: [self filetype]];
		else
			image = NO;

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
		NSDictionary* fileAttr = [fm attributesOfItemAtPath:[self path] error:nil];
		NSDate* fileDate = [fileAttr objectForKey: NSFileModificationDate];
		
		NSDictionary* thumAttr = [fm attributesOfItemAtPath:[self thumbnailPath] error:nil];
		NSDate* thumDate = [thumAttr objectForKey: NSFileModificationDate];
		
		if ([fileDate compare:thumDate] == NSOrderedDescending)
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
		NSImage* orig = [[NSImage alloc] initByReferencingURL: url];
		if (!orig)
			return nil;
		
		BOOL pdf = [[self filetype] isEqual:@"com.adobe.pdf"];
	    thum = [orig imageByScalingProportionallyToSize: NSMakeSize(128, 128) background: pdf ? [NSColor whiteColor] : [NSColor clearColor] ];
		thum = [thum rotated:[self rotationAngle]];
	}
	
	if (thum)
	{
		NSBitmapImageRep *bits = [NSBitmapImageRep imageRepWithData: [thum TIFFRepresentation]];
		
		NSData *data = [bits representationUsingType: NSPNGFileType properties: nil];
		
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:data, @"thumbnail", [self path], @"path", [self metadata], @"imagemetadata", nil];
		
		[NSKeyedArchiver archiveRootObject:dict toFile:thumbPath];
		
		NSDictionary* newAttr = [NSDictionary dictionaryWithObjectsAndKeys:[self created], NSFileCreationDate, [self modified], NSFileModificationDate, nil];
		[fm setAttributes:newAttr ofItemAtPath:thumbPath error:nil];
	}
	return thum;
}

- (NSImage*)thumbnail
{
	if (![self hasThumbnail])
		return [self createThumbnail];

	NSDictionary* dict = [NSKeyedUnarchiver unarchiveObjectWithFile:[self thumbnailPath]];
	if (dict)
		return [[NSImage alloc] initWithData: [dict objectForKey:@"thumbnail"]];
	else
		return nil;
}

- (NSDictionary*)metadata
{
	if ([self hasThumbnail])
	{
		NSDictionary* dict = [NSKeyedUnarchiver unarchiveObjectWithFile:[self thumbnailPath]];
		return [dict objectForKey:@"imagemetadata"];
	}
	else
	{
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:2];
		
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

- (BOOL)hasSubFolders:(BOOL)allowMaybe
{
	if (!folder)
		return NO;
	if (allowMaybe || subFolders != MAYBE)
		return subFolders;
	
	NSDirectoryEnumerator* de = [[NSFileManager defaultManager] enumeratorAtPath:[url path]];
	
	NSString* filename;
	while (filename = [de nextObject])
	{
		NSDictionary* attr = [de fileAttributes];
		if ([[attr objectForKey:NSFileType] isEqual:NSFileTypeDirectory])
		{
			subFolders = YES;
			return subFolders;
		}
	}
	subFolders = NO;
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
	while (de)
	{
		[res insertObject:de atIndex:0];
		de = [de getParent];
	}
	return res;
}

- (NSArray*)getSubItems
{
	if (!folder)
		return nil;
	
	NSFileManager* fm = [NSFileManager defaultManager];
    NSArray* contents = [fm contentsOfDirectoryAtPath: [url path] error:nil];
	
	BOOL sawSubFolders = NO;
	NSMutableArray* res = [NSMutableArray arrayWithCapacity: [contents count]];
	for (NSString* path in contents)
	{
		NSString* fullPath = [[url path] stringByAppendingPathComponent: path];
		if (isVisiblePath(fullPath))
		{
			DirEntry* de = [DirEntry dirEntryWithPath: fullPath];
			if (de && ([de isFolder] || [de isImage]))
			{
				[res addObject: de];
				if ([de isFolder])
					sawSubFolders = YES;
			}
		}
	}
	subFolders = sawSubFolders;
	return [NSArray arrayWithArray: res];	
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
	
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* contents = [fm contentsOfDirectoryAtPath: [url path] error:nil];
	
	NSMutableArray* res = [NSMutableArray arrayWithCapacity: [contents count]];
	for (NSString* path in contents)
	{
		BOOL f;
		NSString* fullPath = [[url path] stringByAppendingPathComponent: path];
		
		if (isVisiblePath(fullPath) && [fm fileExistsAtPath:fullPath isDirectory:&f] && f)
		{
			DirEntry* de = [DirEntry dirEntryWithPath: fullPath];
			if (de)
				[res addObject: de];
		}
	}
	subFolders = [res count] > 0;
	return [NSArray arrayWithArray: res];	
}

+ (NSArray*)getRootItems
{
	NSArray* roots = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	
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
