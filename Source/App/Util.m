//
//  Util.m
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


#import "Util.h"
#import "DirEntry.h"
#import <CommonCrypto/CommonDigest.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSString* md5(NSString* str)
{
    NSData* data = [str dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData* digest = [NSMutableData dataWithLength:CC_MD5_DIGEST_LENGTH];

    // MD5 only names thumbnail cache files; it is not used in a security context.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL ok = CC_MD5([data bytes], (CC_LONG)[data length], [digest mutableBytes]) != NULL;
#pragma clang diagnostic pop
    if (ok)
    {
        NSMutableString* ms = [NSMutableString string];
        unsigned char* bytes = (unsigned char*)[digest bytes];
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
            [ms appendFormat: @"%02x", (int)(bytes[i])];

        return [ms copy];
    }
    return @"";
}

// Reads the hidden / volume flags of the item itself (symlinks are not followed).
static BOOL itemFlags(NSString* path, BOOL* hidden, BOOL* volume)
{
    NSURL* url = [NSURL fileURLWithPath:path];
    NSNumber* h = nil;
    NSNumber* v = nil;
    if (![url getResourceValue:&h forKey:NSURLIsHiddenKey error:nil])
        return NO;
    if (![url getResourceValue:&v forKey:NSURLIsVolumeKey error:nil])
        return NO;
    *hidden = [h boolValue];
    *volume = [v boolValue];
    return YES;
}

NSString* fileUTI(NSString* path)
{
    UTType* type = nil;
    if ([[NSURL fileURLWithPath:path] getResourceValue:&type forKey:NSURLContentTypeKey error:nil] && type)
        return [type identifier];
    return nil;
}

BOOL isVisiblePath(NSString* path)
{
    NSFileManager* fm = [NSFileManager defaultManager];

    BOOL hidden = NO;
    BOOL volume = NO;
    if (!itemFlags(path, &hidden, &volume))
        return NO;

    if (hidden)
        return NO;

    if (volume)
        return NO;

    if ([path isEqualTo:@"/dev"])
        return NO;

    NSDictionary* dict = [fm attributesOfItemAtPath:path error:nil];
    if ([[dict valueForKey:NSFileType] isEqual:NSFileTypeSymbolicLink])
    {
        NSString* actualPath = [fm destinationOfSymbolicLinkAtPath:path error:nil];
        if (![actualPath isAbsolutePath])
            actualPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:actualPath];

        do
        {
            BOOL hidden2 = NO;
            BOOL volume2 = NO;
            if (!itemFlags(actualPath, &hidden2, &volume2))
                return NO;

            if (volume2)
                return YES;
            if (hidden2)
                return NO;

            actualPath = [actualPath stringByDeletingLastPathComponent];
        }
        while (![actualPath isEqual:@"/"]);

        return YES;
    }
    return YES;
}

NSString* expandIfLink(NSString* path)
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSDictionary* dict = [fm attributesOfItemAtPath:path error:nil];
    if ([[dict valueForKey:NSFileType] isEqual:NSFileTypeSymbolicLink])
    {
        NSString* actualPath = [fm destinationOfSymbolicLinkAtPath:path error:nil];
        if (![actualPath isAbsolutePath])
            actualPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:actualPath];
        return fixPathCase(actualPath);
    }
    else
    {
        return path;
    }
}

NSString* fixPathCase(NSString* path)
{
    /*
    FSRef ref;
    OSStatus sts;
    UInt8 actualPath[1000];

    //first get an FSRef for the path
    sts = FSPathMakeRef((const UInt8 *)[path UTF8String], &ref, NULL);
    if (sts) return path;

    //then get a path from the FSRef

    sts = FSRefMakePath(&ref, actualPath, 1000);
    if (sts) return path;

    return [NSString stringWithUTF8String:(const char*)actualPath];
     */
    // todo: verify this works
    return [[[NSURL fileURLWithPath:path] fileReferenceURL] path];
}

NSString* stringFromFileSize(long long theSize)
{
    float floatSize = theSize;
    if (theSize < 1023)
        return ([NSString stringWithFormat:@"%i bytes", (int)theSize]);
    floatSize = floatSize / 1024;

    if (floatSize < 1023)
        return ([NSString stringWithFormat:@"%1.1f KB", floatSize]);
    floatSize = floatSize / 1024;

    if (floatSize < 1023)
        return ([NSString stringWithFormat:@"%1.1f MB", floatSize]);

    floatSize = floatSize / 1024;
    return ([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

void setMenuDelegates(NSMenu* menu, id del, NSArray* menus)
{
    if ([menus containsObject:[menu title]])
    {
        [menu setDelegate:del];
    }

    NSArray* items = [menu itemArray];
    for (NSMenuItem* item in items)
    {
        if ([item hasSubmenu])
            setMenuDelegates([item submenu], del, menus);
    }
}

NSInteger sortFunc(id num1, id num2, void* context)
{
    DirEntry* de1 = (DirEntry*)num1;
    DirEntry* de2 = (DirEntry*)num2;
    int sort = (int)(size_t)context;

    if (sort == BSModified)
    {
        NSComparisonResult res = [[de1 modified] compare: [de2 modified]];
        if (res != NSOrderedSame)
            return res;
    }
    if (sort == BSCreated)
    {
        NSComparisonResult res = [[de1 created] compare: [de2 created]];
        if (res != NSOrderedSame)
            return res;
    }
    if (sort == BSSize)
    {
        long long sz1 = [de1 size];
        long long sz2 = [de2 size];

        if (sz1 < sz2)
            return NSOrderedAscending;
        else if (sz2 < sz1)
            return NSOrderedDescending;
    }
    if (sort == BSKind)
    {
        NSComparisonResult res = [[de1 description] compare: [de2 description]];
        if (res != NSOrderedSame)
            return res;
    }

    return [[de1 displayName] compare: [de2 displayName] options: NSCaseInsensitiveSearch | NSNumericSearch];
}

void addAppsToMenu(NSURL* file, NSMenu* menu, SEL sel, BOOL edit)
{
    while ([menu numberOfItems] > 0)
        [menu removeItemAtIndex:0];

    NSArray* apps = (NSArray*)CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef)file, edit ? kLSRolesEditor : kLSRolesViewer));
    if (apps)
    {
        int i = 0;
        for (NSURL* url in apps)
        {
            DirEntry* de = [DirEntry dirEntryWithURL:url];
            NSMenuItem* item = [menu addItemWithTitle:[de displayName] action:sel keyEquivalent:@""];
            [item setTag: i++];

            NSImage* icon = [de icon];

            NSSize sz = { 17, 17 };
            [icon setSize: sz];

            [item setImage: icon];
        }
    }
}

void openWithApp(NSURL* file, int idx, BOOL edit)
{
    NSArray* apps = (NSArray*)CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef)file, edit ? kLSRolesEditor : kLSRolesViewer));
    if (apps)
    {
        [[NSWorkspace sharedWorkspace] openURLs:@[file] withApplicationAtURL:[apps objectAtIndex:idx] configuration:[NSWorkspaceOpenConfiguration configuration] completionHandler:nil];
    }
}

NSSize shrinkSizeToFit(NSSize rect, NSSize bounds)
{
    if (rect.width <= bounds.width && rect.height <= bounds.height)
        return rect;

    float scaleFactor  = 0.0;

    float widthFactor  = bounds.width  / rect.width;
    float heightFactor = bounds.height / rect.height;

    if ( widthFactor < heightFactor )
        scaleFactor = widthFactor;
    else
        scaleFactor = heightFactor;

    float scaledWidth  = rect.width  * scaleFactor;
    float scaledHeight = rect.height * scaleFactor;

    return NSMakeSize(scaledWidth, scaledHeight);
}

NSRect shrinkRectToFit(NSRect rect, NSRect bounds)
{
    if (rect.size.width <= bounds.size.width && rect.size.height <= bounds.size.height)
    {
        return NSMakeRect((bounds.size.width - rect.size.width) / 2 + bounds.origin.x,
                          (bounds.size.height - rect.size.height) / 2 + bounds.origin.y,
                          rect.size.width, rect.size.height);
    }

    NSSize newSize = shrinkSizeToFit(rect.size, bounds.size);

    return NSMakeRect((bounds.size.width - newSize.width) / 2 + bounds.origin.x,
                      (bounds.size.height - newSize.height) / 2 + bounds.origin.y,
                       newSize.width, newSize.height);
}
