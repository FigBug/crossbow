//
//  BrowserTree.h
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

@class Browser;
@class DirEntry;

@interface BrowserTree : NSObject {
	Browser* browser;
	NSArray* rootItems;
	
	NSMutableSet* deCache;
	NSMutableDictionary* deSubItems;
	
	NSThread* arrowThread;
}

- (id)init:(Browser*)browser;

- (void)selectDirEntry:(DirEntry*)de;
- (DirEntry*)selectedDirEntry;
- (void)devicesChanged:(id)param;
- (NSArray*)getSubFolders:(DirEntry*)de;
- (void)refresh;
- (void)refreshCurrent;

- (void)runArrowThread;
- (void)cancelArrowThread;
- (void)arrowProc:(id)files;
- (void)arrowProcCallback:(id)params;

// FolderTree Protocol
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

// Delegate Protocol
- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (void)outlineViewItemWillCollapse:(NSNotification *)notification;

@end
