//
//  FileListItem.h
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
#import <Quartz/Quartz.h>

@class DirEntry;

@interface FileListItem : NSObject {
	DirEntry* de;
	NSImage* thumb;
	NSString* subtitle;
	int thumbVer;
}

+ (id)fileListItem:(DirEntry*)de;
- (id)init:(DirEntry*)de;

- (BOOL)isEqual:(id)anObject;
- (NSUInteger)hash;

- (DirEntry*)dirEntry;

- (void)setThumb:(NSImage*)image;
- (NSImage*)thumb;

- (NSString*)createSubtitle;

// IKImageBrowserItem
- (id)imageRepresentation;
- (NSString*)imageRepresentationType;
- (NSString*)imageSubtitle;
- (NSString*)imageTitle;
- (NSString*)imageUID;
- (NSUInteger)imageVersion;
- (BOOL)isSelectable;

@end
