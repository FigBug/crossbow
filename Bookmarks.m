//
//  Bookmarks.m
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


#import "Bookmarks.h"
#import "DirEntry.h"
#import "AppController.h"
#import "Preferences.h"

@implementation Bookmarks

- (id)init
{
	if (self = [super init])
	{
		bookmarks = [[NSMutableArray alloc] initWithCapacity: 10];
		
		NSArray* paths = prefsGet(PrefBookmarks);
		
		for (NSString* path in paths)
		{
			DirEntry* de = [DirEntry dirEntryWithPath: path];
			if (de)
				[bookmarks addObject: de];
		}
	}
	return self;
}

- (void)dealloc
{
	[bookmarks release];
	
	[super dealloc];
}

- (NSArray*)bookmarks
{
	return bookmarks;
}

- (int)count
{
	return [bookmarks count];
}

- (DirEntry*)bookmark:(int)idx
{
	return [bookmarks objectAtIndex:idx];
}

- (void)addBookmark:(DirEntry*)de
{
	[bookmarks addObject:de];
	
	NSMutableArray* paths = [NSMutableArray arrayWithCapacity: 10];
	for (DirEntry* de in bookmarks)
		[paths addObject: [de path]];

	prefsSet(PrefBookmarks, [NSArray arrayWithArray: paths]);
}

- (void)deleteBookmark:(int)idx
{
	[bookmarks removeObjectAtIndex:idx];

	NSMutableArray* paths = [NSMutableArray arrayWithCapacity: 10];
	for (DirEntry* de in bookmarks)
		[paths addObject: [de path]];
	
	prefsSet(PrefBookmarks, [NSArray arrayWithArray: paths]);	
}

@end
