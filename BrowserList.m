//
//  BrowserList.m
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


#import "BrowserList.h"
#import "Browser.h"
#import "DirEntry.h"
#import "Viewer.h"
#import "FileListItem.h"

@implementation BrowserList

- (id)init:(Browser*)browser_
{
	if (self = [super init])
	{
		browser = browser_;
	}
	return self;
}

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView*)aBrowser
{
	return [browser.folderContents count];
}

- (id)imageBrowser:(IKImageBrowserView*)aBrowser itemAtIndex:(NSUInteger)index
{
	NSArray* arr = browser.folderContents;
	DirEntry* de = [arr objectAtIndex: index];
	return [browser fileListItemFor:de];
}


- (void)imageBrowser:(IKImageBrowserView*)aBrowser cellWasDoubleClickedAtIndex:(NSUInteger)index
{
	DirEntry* de = [browser.folderContents objectAtIndex: index];
	if ([de isFolder])
	{
		[browser browseToFolder:de sender:browser.fileList];
	}
	else
	{
		NSIndexSet* indexes = [aBrowser selectionIndexes];
		NSMutableArray* imagesToView = [NSMutableArray arrayWithCapacity: [browser.folderContents count]];
		if ([indexes count] >= 2)
		{
			for (int i = (int)[indexes firstIndex]; i <= [indexes lastIndex]; i++)
			{
				if ([indexes containsIndex: i])
				{
					DirEntry* de = [browser.folderContents objectAtIndex: i];
					if ([de isFile])
						[imagesToView addObject: de];
				}
			}
		}
		else
		{
			for (DirEntry* de in browser.folderContents)
			{
				if ([de isFile])
					[imagesToView addObject: de];
			}
		}
		
		DirEntry* first = [browser.folderContents objectAtIndex: index];
		NSInteger startPos = [imagesToView indexOfObject: first];
		if (startPos == NSNotFound)
			startPos = 0;
		
		[browser viewImages:imagesToView atIndex:(int)startPos];
	}
}

- (void)imageBrowser:(IKImageBrowserView*)aBrowser cellWasRightClickedAtIndex:(NSUInteger)index withEvent:(NSEvent*)event
{
	[[browser.fileListContext itemWithTitle:@"View"] setTag:index];
	[NSMenu popUpContextMenu:browser.fileListContext withEvent:event forView:aBrowser];
}

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView*)aBrowser
{
	NSUInteger idx = [[aBrowser selectionIndexes] firstIndex];
	DirEntry* de = (idx == NSNotFound) ? nil : [browser.folderContents objectAtIndex: idx];
	[browser selectionChanged];
	[browser previewFile:de];
	[browser updateStatusBar];
}

@end
