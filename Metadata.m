//
//  Metadata.m
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


#import "Metadata.h"
#import "DirEntry.h"


@implementation Metadata

- (id)init
{
	if (self = [super initWithWindowNibName:@"Metadata"])
	{
	}
	return self;
}

- (void)awakeFromNib
{
}

- (void)setDirEntry:(DirEntry*)de_
{
	if (de == de_)
		return;
	
	de = de_;
	
	metadata = nil;
	if (de)
		metadata = [de metadata];
	
	//[metadataList reloadData];
	//[metadataList expandItem:nil expandChildren:YES];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (!metadata)
		return nil;
	
	if (item == nil)
	{
		NSArray* values = [[metadata allKeys] sortedArrayUsingSelector:@selector(compare:)];
		return [values objectAtIndex:index];
	}
	else
	{
		NSArray* values = [[[self objectForKey:item root:metadata] allKeys] sortedArrayUsingSelector:@selector(compare:)];
		return [values objectAtIndex:index];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (!metadata)
		return NO;

	id obj = [self objectForKey:item root:metadata];
	return obj && [obj isKindOfClass: [NSDictionary class]] && [obj count] > 0;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!metadata)
		return 0;

	if (item == nil)
	{
		return [metadata count];
	}
	else
	{
		id obj = [self objectForKey:item root:metadata];
		if (obj && [obj isKindOfClass: [NSDictionary class]])
			return [obj count];
		else
			return 0;
	}
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (!metadata)
		return nil;

	id obj = [self objectForKey:item root:metadata];
	if (obj && [obj isKindOfClass: [NSDictionary class]])
	{
		if ([[tableColumn identifier] isEqual:@"Name"])
			return [item substringWithRange:NSMakeRange(1, [item length] - 2)];
		else
			return @"";
	}
	else
	{
		if ([[tableColumn identifier] isEqual:@"Name"])
		{
			return item;
		}
		else
		{
			if ([obj isKindOfClass: [NSArray class]])
			{
				NSArray* arr = (NSArray*)obj;
				NSString* res = @"";
				for (id el in arr)
				{
					res = [res stringByAppendingFormat:@"%@ ", el];
				}
				return res;
			}
			else
			{
				return [obj description];				
			}
		}
	}
}

- (id)objectForKey:(id)key root:(NSDictionary*)dict
{
	id res = [dict objectForKey:key];
	if (res) return res;
	
	NSArray* values = [dict allValues];
	for (id val in values)
	{
		if ([val isKindOfClass: [NSDictionary class]])
		{
			res = [self objectForKey:key root:val];
			if (res) return res;
		}
	}
	return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

@end
