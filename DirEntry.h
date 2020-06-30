//
//  DirEntry.h
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


#import <Cocoa/Cocoa.h>

#define MAYBE (BOOL)2

@interface DirEntry : NSObject {
	NSURL* url;
	NSString* displayName;
	BOOL invalid;
	BOOL folder;
	BOOL image;
	BOOL link;
	int subFolders;
	NSDate* creationDate;
	NSDate* modificationDate;
	long long fileSize;
}

+ (DirEntry*)dirEntryWithURL:(NSURL*)url;
+ (DirEntry*)dirEntryWithPath:(NSString*)path;
- (id)initWithURL:(NSURL*)url;
- (void)dealloc;

- (NSString*)description;
- (BOOL)isEqual:(id)anObject;
- (NSUInteger)hash;

+ (NSString*)thumbnailDir;
+ (void)clearAllThumbnails;

- (NSURL*)url;
- (NSString*)path;
- (NSString*)filename;
- (NSString*)filetype;
- (NSString*)filetypeDescription;

- (void)refresh;

- (NSDate*)created;
- (NSDate*)modified;
- (long long)size;

- (NSImage*)icon;
- (NSImage*)image;

- (NSString*)thumbnailPath;
- (BOOL)hasThumbnail;
- (NSImage*)createThumbnail;
- (NSImage*)thumbnail;

- (NSDictionary*)metadata;
- (int)rotationAngle;

+ (NSArray*)imageUTIs;

- (BOOL)isInvalid;
- (BOOL)isFolder;
- (BOOL)isFile;
- (BOOL)isLink;
- (NSString*)displayName;
- (BOOL)isFilesystemRoot;
- (BOOL)isChildOf:(DirEntry*)de;
- (int)hasSubFolders:(BOOL)allowMaybe; // NO = 0, YES = 1, MAYBE = 2

- (DirEntry*)getLinkedDirEntry;

- (DirEntry*)getParent;
- (NSArray*)getHierarchy;
- (NSArray*)getSubItems;
- (NSArray*)deepGetSubItems;
- (NSArray*)getSubFiles;
- (NSArray*)getSubFolders;
+ (NSArray*)getRootItems;

+ (DirEntry*)getDesktop;
+ (DirEntry*)getHome;
+ (DirEntry*)getDocuments;
+ (DirEntry*)getDownloads;

@end
