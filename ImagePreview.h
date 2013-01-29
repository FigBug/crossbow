//
//  ImagePreview.h
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

@interface ImagePreview : NSView {
	NSImage* cachedImage;
	DirEntry* file;
}

@property (nonatomic, retain) NSImage* cachedImage;
@property (nonatomic, retain) DirEntry* file;

- (void)dealloc;

- (void)previewImage:(DirEntry*)de;
- (void)updateNow:(DirEntry*)image;
- (void)drawRect:(NSRect)dirtyRect;

- (void)decodeProc:(NSArray*)params;
- (void)decodeFinished:(NSArray*)params;

@end
