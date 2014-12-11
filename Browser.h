//
//  Browser.h
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
#import "Selection.h"

@class DirEntry;
@class BrowserTree;
@class BrowserList;
@class History;
@class Bookmarks;
@class FileListItem;
@class ImagePreview;

@interface Browser : NSWindowController<NSToolbarDelegate> {
	// Outlets
	IBOutlet NSOutlineView* __weak folderTree;
	IBOutlet ImagePreview* previewPane;
	IBOutlet IKImageBrowserView* __weak fileList;
	IBOutlet NSSplitView* verticalSplit;
	IBOutlet NSSplitView* horizontalSplit;
	IBOutlet NSWindow* browserWindow;
	IBOutlet NSTextField* statusBar;
	IBOutlet NSProgressIndicator* thumbProgress;
	IBOutlet NSMenu* __weak fileListContext;
	IBOutlet NSSlider* thumbSize;
	
	// Path info
	History* history;
	NSArray* folderContents;
	int sort;
	int browserId;
	
	Bookmarks* bookmarks;
	Selection* selection;
	
	// Data Sources
	BrowserTree* browserTree;
	BrowserList* browserList;
	
	NSMutableDictionary* fileListItems;
	
	NSThread* thumbnailThread;
	
	// toolbar
	NSDictionary *toolbaritems;
	NSArray *toolbaridentifiers;
	
	// delete bookmark sheet
	IBOutlet NSWindow* deleteBookmarkSheet;
	IBOutlet NSPopUpButton* bookmarkList;
	
	// go to folder
	IBOutlet NSWindow* gotoFolderSheet;
	IBOutlet NSTextField* gotoFolder;
	IBOutlet NSTextField* gotoFolderError;
}

@property (weak, nonatomic, readonly) NSOutlineView* folderTree;
@property (weak, nonatomic, readonly) IKImageBrowserView* fileList;
@property (nonatomic, strong) NSArray* folderContents;
@property (nonatomic, strong) Selection* selection;
@property (nonatomic, readonly) int browserId;
@property (nonatomic, readonly) NSMutableDictionary* fileListItems;
@property (weak, nonatomic, readonly) NSMenu* fileListContext;

- (BOOL)isEqual:(id)anObject;
- (NSUInteger)hash;

- (void)browseToFolder:(DirEntry*)folder sender:(id)sender;
- (void)refreshLocation;
- (DirEntry*)currentLocation;
- (NSArray*)allFiles;

- (FileListItem*)fileListItemFor:(DirEntry*)de;

- (id)viewImages:(NSArray*)images atIndex:(int)idx;

- (void)cancelThumbnailThread;
- (void)thumbailProc:(id)files;
- (void)thumbnailProcCallback:(id)params;

- (void)previewFile:(DirEntry*)file;
- (void)updateStatusBar;
- (void)selectionChanged;
- (void)selectDirEntry:(DirEntry*)de;

- (NSToolbarItem*)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (void)setupToolbarItems;
- (NSArray*)makeToolbarItems;

- (void)sheetDidEnd: (NSWindow*)sheet returnCode: (int)code contextInfo: (void*) context;
- (void)windowWillClose:(NSNotification *)notification;

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;

- (void)menuNeedsUpdate:(NSMenu*)menu;
- (BOOL)menuHasKeyEquivalent:(NSMenu*)menu forEvent:(NSEvent*)event target:(id*)target action:(SEL*)action;

- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)up:(id)sender;
- (IBAction)bookmark:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (IBAction)recent:(id)sender;
- (IBAction)slideshow:(id)sender;
- (IBAction)sort:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)revealFileInFinder:(id)sender;
- (IBAction)openInViewer:(id)sender;
- (IBAction)openInEditor:(id)sender;
- (IBAction)viewSelection:(id)sender;
- (IBAction)deleteBookmark:(id)sender;
- (IBAction)deleteBookmarkFinished:(id)sender;
- (IBAction)thumbnailsDeleted:(id)param;
- (IBAction)gotoFolder:(id)sender;
- (IBAction)gotoFolderFinished:(id)sender;
- (IBAction)showMetadata:(id)sender;
- (IBAction)setThumbsize:(id)sender;
- (IBAction)buildThumbnails:(id)sender;
- (IBAction)share:(id)sender;
- (IBAction)createArchive:(id)sender;
- (IBAction)moveToTrash:(id)sender;

@end
