//
//  FileListItem.m
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


#import "FileListItem.h"
#import "DirEntry.h"

static int baseThumbVer = 1;

@implementation FileListItem

+ (id)fileListItem:(DirEntry*)de
{
	return [[FileListItem alloc] init:de];
}

- (id)init:(DirEntry*)de_
{
	if (self = [super init])
	{
		de = de_;
		
		thumbVer = ++baseThumbVer;
		
		if ([de hasThumbnail])
		{
			thumb = [de thumbnail];
			subtitle = [self createSubtitle];

			thumbVer++;
		}
	}
	return self;
}


- (BOOL)isEqual:(id)anObject
{
	return [de isEqual:[anObject dirEntry]];
}

- (NSUInteger)hash
{
	return [de hash];
}

- (DirEntry*)dirEntry
{
	return de;
}

- (void)setThumb:(NSImage*)image
{
	thumb = image;

	thumbVer++;
	
	subtitle = [self createSubtitle];
}

- (NSImage*)thumb
{
	return thumb;
}

- (id)imageRepresentation
{
	if (thumb)
		return thumb;
	else
		return nil;
}

- (NSString *)imageRepresentationType
{
	return IKImageBrowserNSImageRepresentationType;
}

- (NSString*)imageSubtitle
{
	if (subtitle)
		return subtitle;
	return @"";
}

- (NSString*)createSubtitle
{
	if ([de hasThumbnail])
	{
		NSDictionary* metadata = [de metadata];
		
		NSNumber* width  = [metadata objectForKey:(NSString*)kCGImagePropertyPixelWidth];
		NSNumber* height = [metadata objectForKey:(NSString*)kCGImagePropertyPixelHeight];
		NSNumber* orient = [metadata objectForKey:(NSString*)kCGImagePropertyOrientation];
		NSNumber* depth  = [metadata objectForKey:(NSString*)kCGImagePropertyDepth];
		NSString* model  = [metadata objectForKey:(NSString*)kCGImagePropertyColorModel];
		
		if (width && height)
		{
			NSString* title;
			if (orient && [orient intValue] == 6 || [orient intValue] == 8)
				title = [NSString stringWithFormat:@"%@ x %@", height, width];
			else
				title = [NSString stringWithFormat:@"%@ x %@", width, height];
			
			if (depth && model)
				title = [title stringByAppendingFormat:@" (%@ %@)", depth, model];
			
			return title;
		}
	}
	return @"";
}

- (NSString *)imageTitle
{
	return [de displayName];
}

- (NSString *)imageUID
{
	return [de path];
}

- (NSUInteger)imageVersion
{
	if (thumb)
		return thumbVer;
	else
		return 0;
}

- (BOOL)isSelectable
{
	return YES;
}

@end
