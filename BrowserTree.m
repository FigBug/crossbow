//
//  BrowserTree.m
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


#import "BrowserTree.h"
#import "Browser.h"
#import "DirEntry.h"
#import "Util.h"

@implementation BrowserTree

- (id)init:(Browser*)browser_
{
	if (self = [super init])
	{
		browser   = browser_;
		
		deCache = [[NSMutableSet alloc] initWithCapacity: 100];
		deSubItems = [[NSMutableDictionary alloc] initWithCapacity: 100];
		
		NSWorkspace* ws = [NSWorkspace sharedWorkspace];
		[[ws notificationCenter] addObserver:self selector:@selector(devicesChanged:) name:@"NSWorkspaceDidMountNotification" object:ws];
		[[ws notificationCenter] addObserver:self selector:@selector(devicesChanged:) name:@"NSWorkspaceDidUnmountNotification" object:ws];
	}
	return self;
}

- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	
	[deCache release];
	[deSubItems release];
	
	[super dealloc];
}

- (NSArray*)getSubFolders:(DirEntry*)de
{
	NSString* key = de ? [de path] : @"(null)";
	
	NSArray* res = [deSubItems objectForKey:key];
	if (res)
		return res;
	
	res = de ? [[de getSubFolders] sortedArrayUsingFunction:sortFunc context:(void*)BSName] : [DirEntry getRootItems];
	
	[deSubItems setObject:res forKey:key];
	[deCache addObjectsFromArray:res];
	
	return res;
}

- (void)devicesChanged:(id)param
{
	[deSubItems removeObjectForKey:@"(null)"];
	[browser.folderTree reloadData];
}

- (void)refresh
{
	[deSubItems removeAllObjects];
	[browser.folderTree reloadData];
}

- (void)refreshCurrent
{
	DirEntry* de = [self selectedDirEntry];
	if (!de)
		return;
	
	[deSubItems removeObjectForKey:[de path]];
	[browser.folderTree reloadItem:de];
}

- (void)runArrowThread
{
	[self cancelArrowThread];
	
	NSOutlineView* ov = browser.folderTree;
	NSMutableArray* items = [NSMutableArray arrayWithCapacity:[ov numberOfRows]];
	for (int i = 0; i < [ov numberOfRows]; i++)
		[items addObject:[ov itemAtRow:i]];
	
	arrowThread = [[NSThread alloc] initWithTarget:self selector:@selector(arrowProc:) object:items];
	[arrowThread start];
}

- (void)cancelArrowThread
{
	if (arrowThread)
	{
		[arrowThread cancel];
		[arrowThread release];
		arrowThread = nil;
	}
}

- (void)arrowProc:(id)files
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	int done = 0;
	for (DirEntry* de in files)
	{
		if ([[NSThread currentThread] isCancelled])
		{
			[pool release];
			return;
		}

		if ([de hasSubFolders:YES] == MAYBE)
		{
			[de hasSubFolders:NO];
			done++;
			
			if (done % 5 == 0)
			{
				[self performSelectorOnMainThread:@selector(arrowProcCallback:) withObject:@"working" waitUntilDone:NO];
			}
		}
	}
	[self performSelectorOnMainThread:@selector(arrowProcCallback:) withObject:@"finished" waitUntilDone:NO];
	
	[pool release];
}

- (void)arrowProcCallback:(id)params
{
	NSString* status = (NSString*)params;
	
	[browser.folderTree reloadData];
	
	if ([status isEqual:@"finished"])
	{
		[arrowThread release];
		arrowThread = nil;
	}
}

- (void)selectDirEntry:(DirEntry*)de
{
	NSArray* hierarchy = [de getHierarchy];
	
	for (DirEntry* parentDe in hierarchy)
		[browser.folderTree expandItem:parentDe];
	
	int row = [browser.folderTree rowForItem:de];
	if (row != -1)
	{
		[browser.folderTree selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[browser.folderTree scrollRowToVisible:row];
	}
}

- (DirEntry*)selectedDirEntry
{
	int index = [browser.folderTree selectedRow];
	if (index == -1)
		return nil;
	
	DirEntry* de = [browser.folderTree itemAtRow:index];
	return de;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item)
	{
		DirEntry* de = (DirEntry*)item;
		return [[self getSubFolders:de] objectAtIndex:index];
	}
	else
	{
		return [[self getSubFolders:nil] objectAtIndex:index];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	DirEntry* de = (DirEntry*)item;
	BOOL subFolders = [de hasSubFolders:YES];
	if (subFolders == YES || subFolders == MAYBE)
		return YES;
	else
		return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item)
	{
		DirEntry* de = (DirEntry*)item;
		return [[self getSubFolders:de] count];
	}
	else
	{
		return [[self getSubFolders:nil] count];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (item)
	{
		DirEntry* de = (DirEntry*)item;
		return [de displayName];
	}
	return @"";
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSOutlineView* folderTree = [notification object];
	DirEntry* de = [folderTree itemAtRow: [folderTree selectedRow]];
	if (![de isEqual:[browser currentLocation]])
		[browser browseToFolder:de sender:folderTree];
}

- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
	DirEntry* de = [[notification userInfo] objectForKey:@"NSObject"];
	DirEntry* sel = [self selectedDirEntry];
	
	if (sel && [sel isChildOf: de])
	{
		int row = [browser.folderTree rowForItem:de];
		if (row != -1)
		{
			[browser.folderTree selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			[browser.folderTree scrollRowToVisible:row];
		}
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (item)
	{
		NSSize sz = { 17, 17 };
		
		DirEntry* de = (DirEntry*)item;
		NSImage* icon = [de icon];
		[icon setSize: sz];
		[cell setImage: icon];
		[cell setLeaf:YES];
	}
}

@end
