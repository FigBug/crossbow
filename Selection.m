//
//  Selection.m
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


#import "Selection.h"
#import "DirEntry.h"
#import "Util.h"

@implementation Selection

+ (Selection*)selectionWith:(NSArray*)list
{
	Selection* s = [[Selection alloc] initWith:list];
	
	return s;
}

- (id)initWith:(NSArray*)list
{
	if (self = [super init])
	{
		selectedItems = list;
		
		NSMutableArray* files   = [NSMutableArray arrayWithCapacity: 10];
		NSMutableArray* folders = [NSMutableArray arrayWithCapacity: 10];
		
		for (DirEntry* de in list)
		{
			if ([de isFolder])
				[folders addObject: de];
			else
				[files addObject: de];
		}
		
		selectedFiles   = [[NSArray alloc] initWithArray: files];
		selectedFolders = [[NSArray alloc] initWithArray: folders];
	}
	return self;
}


- (int)count
{
	return [selectedItems count];
}

- (int)countFiles
{
	return [selectedFiles count];
}

- (int)countFolders
{
	return [selectedFolders count];
}

- (NSArray*)selection
{
	return [selectedFolders arrayByAddingObjectsFromArray: selectedFiles];
}

- (NSArray*)selectedFiles
{	
	return selectedFiles;
}

- (NSArray*)selectedFolders
{
	return selectedFolders;
}

- (NSArray*)expandSelection:(int)sort
{
	NSMutableArray* res = [NSMutableArray arrayWithCapacity: [self countFiles]];
	for (DirEntry* de in selectedItems)
	{
		if ([de isFile])
		{
			[res addObject: de];
		}
		else
		{
			[res addObjectsFromArray: [[de getSubFiles] sortedArrayUsingFunction:sortFunc context:(void*)sort]];
		}
	}
	return res;
}

- (BOOL)onlyOneFile
{
	return [selectedItems count] == 1 && [selectedFiles count] == 1;
}

- (DirEntry*)firstFile
{
	return ([selectedFiles count] > 0) ? [selectedFiles objectAtIndex:0] : nil;
}

- (NSArray*)deepExpandSelection:(int)sort
{
	NSMutableArray* res = [NSMutableArray arrayWithCapacity: [self countFiles]];
	
	NSMutableArray* folders = [NSMutableArray arrayWithCapacity:10];
	
	for (DirEntry* de in selectedItems)
	{
		[res addObject:de];
		if ([de isFolder])
			[folders addObject:de];
	}
	while ([folders count] > 0)
	{
		DirEntry* folder = [folders objectAtIndex:0];
		
		NSArray* sub = [[folder getSubItems] sortedArrayUsingFunction:sortFunc context:(void*)sort];
		for (DirEntry* de in sub)
		{
			[res addObject:de];
			if ([de isFolder])
				[folders addObject:de];
		}
		
		[folders removeObjectAtIndex:0];
	}
	
	return res;
}

@end
