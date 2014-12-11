//
//  Viewer.h
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

#include "ActivityFaker.h"

enum Zoom
{
	ZoomFit,
	ZoomActual,
	ZoomFree,
};

@class Metadata;
@class ImageClip;
@class ImageView;
@class ImageCache;

@interface Viewer : NSWindowController<NSToolbarDelegate> {
	IBOutlet ImageClip* imageClip;
	IBOutlet ImageView* imageView;
	
	IBOutlet NSWindow* viewerWindow;
	IBOutlet NSMenu* viewerMenu;
	IBOutlet NSTextField* statusBar;

	int firstImage;
	int curImage;
	
	int associatedBrowser;
	
	int zoomMode;
	double zoomFactor;
	
	NSArray* images;
	
	NSTimer* slideshowTimer;
	
	ImageCache* imageCache;
    
    ActivityFaker* activityFaker;
	
	// toolbar
	NSDictionary *toolbaritems;
	NSArray *toolbaridentifiers;
	
	// slideshow delay
	IBOutlet NSWindow* slideshowDelaySheet;
	IBOutlet NSTextField* slideshowDelay;
	IBOutlet NSStepper* slideshowDelayStep;
	
	// goto image
	IBOutlet NSWindow* gotoImageSheet;
	IBOutlet NSTextField* gotoImageNumber;
	IBOutlet NSTextField* gotoImageMax;
	
	// image list drawer
	IBOutlet NSTableView* imageList;
	IBOutlet NSDrawer* imageListDrawer;
}

@property (nonatomic, strong) NSArray* images;

- (id)init:(NSArray*)images atIndex:(int)index;

- (void)awakeFromNib;

-(NSToolbarItem*)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag;
-(NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
-(void)setupToolbarItems;
-(NSArray*)makeToolbarItems;

- (void)viewImage:(int)imageIndex;
- (void)updateZoom;

- (void)fillCache;

- (void)setAssociatedBrowser:(int)browseId;

- (void)windowDidResize:(NSNotification *)notification;
- (void)windowWillClose:(NSNotification *)notification;
- (void)menuNeedsUpdate:(NSMenu*)menu;
- (BOOL)menuHasKeyEquivalent:(NSMenu*)menu forEvent:(NSEvent*)event target:(id*)target action:(SEL*)action;

- (void)slideshowCallback:(NSTimer*)timer;
- (void)updateStatusBar;

- (IBAction)fullscreen:(id)sender;

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item;
- (void)sheetDidEnd: (NSWindow*)sheet returnCode: (int)code contextInfo: (void*) context;

- (BOOL)slideshowRunning;

- (IBAction)previousImage:(id)sender;
- (IBAction)nextImage:(id)sender;
- (IBAction)firstImage:(id)sender;
- (IBAction)lastImage:(id)sender;

- (IBAction)zoomFit:(id)sender;
- (IBAction)zoomActual:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

- (IBAction)openDocument:(id)sender;
- (IBAction)slideshow:(id)sender;
- (IBAction)openRecent:(id)sender;

- (IBAction)sort:(id)sender;

- (IBAction)rotateCw:(id)sender;
- (IBAction)rotateCcw:(id)sender;

- (IBAction)showMetadata:(id)sender;

- (IBAction)pan:(id)sender;

// slideshow delay
- (IBAction)slideshowDelay:(id)sender;
- (IBAction)slideshowDelayFinished:(id)sender;
- (IBAction)slideshowDelayStepped:(id)sender;
- (void)controlTextDidChange:(NSNotification*)aNotification;

// goto image
- (IBAction)gotoImage:(id)sender;
- (IBAction)gotoImageFinished:(id)sender;

// image list
- (id)tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (IBAction)toggleDrawer:(id)sender;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (void)drawerDidOpen:(NSNotification*)notification;
- (void)drawerDidClose:(NSNotification *)notification;
- (NSSize)drawerWillResizeContents:(NSDrawer*)sender toSize:(NSSize)contentSize;

// image clip delegate
- (void)imageClipClose:(id)param;
- (void)imageClipPrevious:(id)param;
- (void)imageClipNext:(id)param;

@end
