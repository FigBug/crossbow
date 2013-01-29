//
//  Viewer.m
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


#import "Viewer.h"
#import "ImageClip.h"
#import "ImageView.h"
#import "DirEntry.h"
#import "Util.h"
#import "Preferences.h"
#import "SegmentedToolbarItem.h"
#import "AppController.h"
#import "NSArrayAdditions.h"
#import "NSImageAdditions.h"
#import "Metadata.h"
#import "Browser.h"
#import "ImageCache.h"

double zoomSettings[] = { 0.01, 0.02, 0.03, 0.05, 0.07, 0.10, 0.15, 0.20, 0.30, 0.50, 0.70, 1.00, 1.50, 2.00, 3.00, 5.00, 7.00, 10.00, 20.00, 30.00, 50.00, 70.00, 100.00 };
int numZoomSettings = sizeof(zoomSettings) / sizeof(zoomSettings[0]);

int prevImg(int idx, int max)
{
	idx--;
	if (idx < 0)
		idx = max - 1;
	return idx;
}

int nextImg(int idx, int max)
{
	idx++;
	if (idx >= max)
		idx = 0;
	return idx;
}

@implementation Viewer

@synthesize images;

- (id)init:(NSArray*)images_ atIndex:(int)index
{
	if (self = [super initWithWindowNibName:@"Viewer" owner:self])
	{
		firstImage = index;
		curImage = -1;
		self.images = images_;
		
		zoomMode = [prefsGet(PrefZoomMode) intValue];
		zoomFactor = 1.0;
		
		associatedBrowser = 0;
		
		imageCache = [[ImageCache alloc] init];
		
		[self showWindow:self];
	}
	return self;
}

- (void)dealloc
{
	self.images = nil;
	
	[imageCache release];
	[toolbaritems release];
	[toolbaridentifiers release];		
	
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
	NSMenu* browserMenu = [[AppController sharedAppController] defaultMainMenu];
	setMenuDelegates(browserMenu, nil, [NSArray arrayWithObjects: @"File", @"Open Recent", @"Arrange By", @"Recent", @"Go", @"Open in Editor", @"Open in Viewer", nil]);
	[[NSApplication sharedApplication] setMainMenu: browserMenu];
	
	if (slideshowTimer)
	{
		[slideshowTimer invalidate];
		slideshowTimer = nil;
	}	
	[self autorelease];
}

- (void)windowDidLoad
{
	[self viewImage: firstImage];
	
	[viewerWindow makeKeyAndOrderFront:self];
	
	int width = [prefsGet(PrefImageListWidth) intValue];
	[imageListDrawer setContentSize:NSMakeSize(width, 0)];
	if ([prefsGet(PrefImageListOpen) boolValue])
		[imageListDrawer open];	
}

- (void)awakeFromNib
{
	// set up image view
	imageView = [[[ImageView alloc] initWithFrame:[imageClip frame]] autorelease];
	[imageClip setDocument:imageView];
	
	// setup toolbar
	NSToolbar *toolbar= [[[NSToolbar alloc] initWithIdentifier:@"ViewerToolbar"] autorelease];
	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[self setupToolbarItems];
	[viewerWindow setToolbar:toolbar];	
	
	[imageList reloadData];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	setMenuDelegates(viewerMenu, self, [NSArray arrayWithObjects:@"View", @"File", @"Open Recent", @"Open in Viewer", @"Open in Editor", nil]);
	[[NSApplication sharedApplication] setMainMenu: viewerMenu];
	
	Metadata* metadataPanel = [[AppController sharedAppController] metadataPanel:NO];
	if (metadataPanel && curImage >= 0)
		[metadataPanel setDirEntry:[images objectAtIndex:curImage]];	
}

- (void)windowDidResize:(NSNotification *)notification
{
	[self updateZoom];
	[self updateStatusBar];
}

- (void)setAssociatedBrowser:(int)browserId
{
	associatedBrowser = browserId;
}

- (void)viewImage:(int)imageIndex
{
	if (curImage != imageIndex)
	{
		DirEntry* de = (images && imageIndex >= 0 && imageIndex < [images count]) ? [images objectAtIndex: imageIndex] : nil;
		if (de)
		{
			curImage = imageIndex;
			
			NSImage* img = [imageCache imageForDirEntry:de];
			
			int angle = [de rotationAngle];
									
			[imageView setImage:img rotationAngle:angle];
			[imageView setOpaque:[[de filetype] isEqual:@"com.adobe.pdf"]];
			[imageClip centerImage];
			
			[self updateZoom];
			
			[imageList selectRowIndexes:[NSIndexSet indexSetWithIndex:imageIndex] byExtendingSelection:NO];
			[imageList scrollRowToVisible: imageIndex];
			
			[viewerWindow setTitleWithRepresentedFilename: [de path]];
			
			[self fillCache];
		}
		else
		{
			[viewerWindow setTitle:@"Viewer"];
		}
		
		Metadata* metadataPanel = [[AppController sharedAppController] metadataPanel:NO];
		if (metadataPanel)
			[metadataPanel setDirEntry:[images objectAtIndex:curImage]];
		
		[self updateStatusBar];
	}
}

- (void)fillCache
{
	int max = [images count];
	int imagesToCache[5] = { curImage, nextImg(curImage, max), prevImg(curImage, max), nextImg(nextImg(curImage, max), max), prevImg(prevImg(curImage, max), max) };
	
	NSMutableArray* list = [NSMutableArray arrayWithCapacity:5];
	for (int i = 0; i < 5; i++)
	{
		DirEntry* de = [images objectAtIndex:imagesToCache[i]];
		if (![list containsObject:de])
			[list addObject:de];
	}
	[imageCache cacheDirEntries:list];
}

- (void)updateZoom
{
	if (zoomMode == ZoomFit)
	{
		NSSize sz = shrinkSizeToFit([imageView originalSize], [imageClip bounds].size);
		zoomFactor =  sz.width / [imageView originalSize].width;
		
		if (zoomFactor > 1.0)
			zoomFactor = 1.0;
		
		[imageView setZoom:zoomFactor];
	}
	else if (zoomMode == ZoomActual)
	{
		zoomFactor = 1.0;
		[imageView setZoom:zoomFactor];
	}
	else if (zoomMode == ZoomFree)
	{
		[imageView setZoom:zoomFactor];
	}
}

- (void)slideshowCallback:(NSTimer*)timer
{
	[self nextImage: self];
	
	UpdateSystemActivity(UsrActivity);
}

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag 
{
	return [toolbaritems objectForKey:identifier];
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return toolbaridentifiers;
}

-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:@"nav", @"zoom", @"rotate", @"slideshow", NSToolbarFlexibleSpaceItemIdentifier, nil];
}

-(void)setupToolbarItems
{
	NSArray *items = [self makeToolbarItems];
	if (!items) 
		return;
	
	NSEnumerator *enumerator;
	NSToolbarItem *item;
	
	[toolbaritems release];
	[toolbaridentifiers release];
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[items count]];
	enumerator = [items objectEnumerator];
	
	while (item=[enumerator nextObject]) 
		[dict setObject:item forKey:[item itemIdentifier]];
	
	toolbaritems = [[NSDictionary dictionaryWithDictionary:dict] retain];
	
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[items count]+3];
	enumerator = [items objectEnumerator];
	
	while (item = [enumerator nextObject]) 
		[array addObject:[item itemIdentifier]];
	
	[array addObject:NSToolbarSeparatorItemIdentifier];
	[array addObject:NSToolbarSpaceItemIdentifier];
	[array addObject:NSToolbarFlexibleSpaceItemIdentifier];
	
	toolbaridentifiers = [[NSArray arrayWithArray:array] retain];
}

-(NSArray *)makeToolbarItems
{
	NSMutableArray *array = [NSMutableArray array];
	
	SegmentedToolbarItem* tool;
	
    tool = [SegmentedToolbarItem itemWithIdentifier:@"nav" label:@"Navigation" paletteLabel:@"Navigation" segments:4];
	[tool setSegment:0 imageName:@"TBFirst" longLabel:@"First" target:nil action:@selector(firstImage:)];
	[tool setSegment:1 imageName:NSImageNameGoLeftTemplate longLabel:@"Previous" target:nil action:@selector(previousImage:)];
	[tool setSegment:2 imageName:NSImageNameGoRightTemplate longLabel:@"Next" target:nil action:@selector(nextImage:)];
	[tool setSegment:3 imageName:@"TBLast" longLabel:@"Last" target:nil action:@selector(lastImage:)];
	[tool setupView];
	[array addObject:tool];

    tool = [SegmentedToolbarItem itemWithIdentifier:@"zoom" label:@"Zoom" paletteLabel:@"Zoom" segments:4];
	[tool setSegment:0 imageName:@"TBZoomIn" longLabel:@"Zoom In" target:self action:@selector(zoomIn:)];
	[tool setSegment:1 imageName:@"TBZoomOut" longLabel:@"Zoom Out" target:self action:@selector(zoomOut:)];
	[tool setSegment:2 imageName:@"TBZoomFit" longLabel:@"Zoom Fit" target:self action:@selector(zoomFit:)];
	[tool setSegment:3 imageName:@"TBZoomActual" longLabel:@"Zoom Actual Size" target:self action:@selector(zoomActual:)];
	[tool setupView];
	[array addObject:tool];
	
	tool = [SegmentedToolbarItem itemWithIdentifier:@"rotate" label:@"Rotate" paletteLabel:@"Rotate" segments:2];
	[tool setSegment:0 imageName:@"TBCw" longLabel:@"Rotate CW" target:self action:@selector(rotateCw:)];
	[tool setSegment:1 imageName:@"TBCcw" longLabel:@"Rotate CCW" target:self action:@selector(rotateCcw:)];
	[tool setupView];
	[array addObject:tool];
	
	tool = [ToolItem itemWithIdentifier:@"slideshow" label:@"Slideshow" paletteLabel:@"Slideshow" imageName:NSImageNameSlideshowTemplate 
							  longLabel:@"Slideshow" action:@selector(slideshow:) activeSelector:@selector(slideshowRunning) target:self];
	[array addObject:tool];
	
	return array;
}

- (void)updateStatusBar
{
	if (!images || [images count] == 0  || curImage == -1)
	{
		[statusBar setStringValue:@""];
	}
	else
	{
		DirEntry* de = [images objectAtIndex: curImage];
		NSString* str = [NSString stringWithFormat: @"%d/%d  |  %@  |  %d%%", curImage + 1, [images count], stringFromFileSize([de size]), (int)(zoomFactor * 100 + 0.5)];
		
		[statusBar setStringValue:str];
	}
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	if ([[menu title] isEqual:@"View"])
	{
		[[menu itemWithTitle:@"Slideshow"] setState: [self slideshowRunning] ? NSOnState : NSOffState];
		
		if ([imageListDrawer state] == NSDrawerOpenState || [imageListDrawer state] == NSDrawerOpeningState)
			[[menu itemWithTitle:@"Show Image List Drawer"] setTitle:@"Hide Image List Drawer"];
		else
			[[menu itemWithTitle:@"Hide Image List Drawer"] setTitle:@"Show Image List Drawer"];
	}
	if ([[menu title] isEqual:@"File"])
	{
		BOOL enable = ([images count] > 0);
		[[menu itemWithTitle:@"Open in Editor"] setEnabled:enable];
		[[menu itemWithTitle:@"Open in Viewer"] setEnabled:enable];
	}	
	if ([[menu title] isEqual:@"Open in Editor"])
	{
		if ([images count] > 0)
			addAppsToMenu([[images objectAtIndex:curImage] url], menu, @selector(openInEditor:), YES);
	}
	if ([[menu title] isEqual:@"Open in Viewer"])
	{
		if ([images count] > 0)
			addAppsToMenu([[images objectAtIndex:curImage] url], menu, @selector(openInViewer:), NO);
	}	
	if ([[menu title] isEqual:@"Open Recent"])
	{
		while ([menu numberOfItems] > 1)
			[menu removeItemAtIndex:0];
		
		NSArray* recent = prefsGet(PrefRecentFiles);
		if ([recent count] > 0)
		{
			[menu insertItem: [NSMenuItem separatorItem] atIndex:0];			
			for (NSString* path in recent)
			{
				DirEntry* de = [DirEntry dirEntryWithPath:path];
				NSMenuItem* item = [menu insertItemWithTitle:[de displayName] action:@selector(openRecent:) keyEquivalent:@"" atIndex:0];
				[item setTag: [recent indexOfObject:path]];
				
				NSImage* icon = [de icon];
				
				NSSize sz = { 17, 17 };
				[icon setSize: sz];			
				
				[item setImage: icon];								
			}
		}
	}
}

- (BOOL)menuHasKeyEquivalent:(NSMenu*)menu forEvent:(NSEvent*)event target:(id*)target action:(SEL*)action
{
	if ([[event characters] isEqual:@" "])
	{
		*target = self;
		*action = @selector(imageClipClose:);
		return YES;
	}
	return NO;
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
	SEL sel = [item action];
	if (sel == @selector(openDocument:) ||
		sel == @selector(openRecent:))
	{
		return YES;
	}
	
	return images && [images count] >= 0;
}

- (void)sheetDidEnd: (NSWindow*)sheet returnCode: (int)code contextInfo: (void*) context
{
}

- (BOOL)slideshowRunning
{
	return slideshowTimer != nil;
}

- (IBAction)fullscreen:(id)sender
{
	NSDictionary* opts = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt: 0], NSFullScreenModeAllScreens, nil];
	if ([imageClip isInFullScreenMode])
		[imageClip exitFullScreenModeWithOptions:opts];
	else
		[imageClip enterFullScreenMode:[NSScreen mainScreen] withOptions:opts];
	
	[self updateZoom];
}

- (IBAction)previousImage:(id)sender
{
	int idx = curImage - 1;
	if (idx < 0)
		idx = [images count] - 1;
	
	[self viewImage: idx];
}

- (IBAction)nextImage:(id)sender
{
	int idx = curImage + 1;
	if (idx >= [images count])
		idx = 0;
	
	[self viewImage: idx];
}

- (IBAction)firstImage:(id)sender
{
	[self viewImage: 0];
}

- (IBAction)lastImage:(id)sender
{
	[self viewImage: [images count] - 1];
}

- (IBAction)zoomFit:(id)sender
{
	zoomMode = ZoomFit;
	prefsSet(PrefZoomMode, [NSNumber numberWithInt:zoomMode]);
	
	[self updateZoom];
	[self updateStatusBar];
}

- (IBAction)zoomActual:(id)sender
{
	zoomMode = ZoomActual;
	prefsSet(PrefZoomMode, [NSNumber numberWithInt:zoomMode]);
	
	[self updateZoom];
	[self updateStatusBar];
}

- (IBAction)zoomIn:(id)sender
{
	zoomMode = ZoomFree;
	prefsSet(PrefZoomMode, [NSNumber numberWithInt:zoomMode]);
	
	for (int i = 0; i < numZoomSettings; i++)
	{
		if (zoomSettings[i] > zoomFactor)
		{
			zoomFactor = zoomSettings[i];
			break;
		}
	}
	
	[self updateZoom];
	[self updateStatusBar];
}

- (IBAction)zoomOut:(id)sender
{
	zoomMode = ZoomFree;
	prefsSet(PrefZoomMode, [NSNumber numberWithInt:zoomMode]);
	
	for (int i = numZoomSettings - 1; i >= 0; i--)
	{
		if (zoomSettings[i] < zoomFactor)
		{
			zoomFactor = zoomSettings[i];
			break;
		}
	}	
	
	[self updateZoom];	
	[self updateStatusBar];
}

- (IBAction)openDocument:(id)sender
{
	NSOpenPanel* open = [NSOpenPanel openPanel];
	[open setDelegate:[AppController sharedAppController]];
	[open setCanChooseFiles: YES];
	[open setCanChooseDirectories: NO];
	[open setResolvesAliases: YES];
	[open setAllowsMultipleSelection: YES];
	
	if ([open runModalForDirectory: nil file:nil types: nil] == NSOKButton)
	{
		NSMutableArray* files  = [NSMutableArray arrayWithCapacity: 10];
		NSMutableArray* recent = [NSMutableArray arrayWithCapacity: 10];
		[recent addObjectsFromArray: prefsGet(PrefRecentFiles)];
		
		for (NSString* file in [open filenames])
		{
			[files addObject: [DirEntry dirEntryWithPath: file]];
			if ([recent containsObject:file])
				[recent removeObject:file];			
			[recent addObject:file];
		}
		while ([recent count] > 10)
			[recent removeObjectAtIndex: 0];
		
		prefsSet(PrefRecentFiles, recent);
		
		if (!self.images)
			self.images = [NSArray array];

		int idx = [images count];
		self.images = [images arrayByAddingObjectsFromArray:files];
		[self viewImage: idx];
		[imageList reloadData];
	}
}

- (IBAction)slideshow:(id)sender
{
	if (slideshowTimer)
	{
		[slideshowTimer invalidate];
		slideshowTimer = nil;
	}
	else
	{
		int delay = [prefsGet(PrefSlideshowDelay) intValue];
		slideshowTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(slideshowCallback:) userInfo:nil repeats:YES];
	}
}

- (IBAction)openRecent:(id)sender
{
	NSMenuItem* item = (NSMenuItem*)sender;
	NSArray* files = prefsGet(PrefRecentFiles);
	DirEntry* de = [DirEntry dirEntryWithPath: [files objectAtIndex:[item tag]]];
	
	if (self.images)
		self.images = [images arrayByAddingObject:de];
	else
		self.images = [NSArray arrayWithObject:de];
		
	[self viewImage:[images count] - 1];
	[imageList reloadData];
}

- (IBAction)openInViewer:(id)sender
{
	openWithApp([[images objectAtIndex:curImage] url], [sender tag], NO);
}

- (IBAction)openInEditor:(id)sender
{
	openWithApp([[images objectAtIndex:curImage] url], [sender tag], YES);	
}

- (IBAction)sort:(id)sender
{
	DirEntry* de = [images objectAtIndex:curImage];
	
	int sort = [sender tag];
	if (sort == -1)
		self.images = [NSArray shuffledArrayWithArray:self.images];
	else
		self.images = [self.images sortedArrayUsingFunction:sortFunc context:(void*)sort];
	
	[imageList reloadData];
	[self viewImage:[self.images indexOfObject:de]];
}

- (IBAction)rotateCw:(id)sender
{
	int or = [imageView angle];
	switch (or)
	{
		case 0  : or = 270; break;
		case 90 : or = 0;   break;
		case 180: or = 90;  break;
		case 270: or = 180; break;
	}
	[imageView setAngle:or];
	
	[self updateZoom];
	[self updateStatusBar];
}

- (IBAction)rotateCcw:(id)sender
{
	int or = [imageView angle];
	switch (or)
	{
		case 0  : or = 90;  break;
		case 90 : or = 180; break;
		case 180: or = 270; break;
		case 270: or = 0;   break;
	}
	[imageView setAngle:or];
	
	[self updateZoom];
	[self updateStatusBar];
}

- (IBAction)showMetadata:(id)sender
{
	Metadata* metadataPanel = [[AppController sharedAppController] metadataPanel:YES];	
	NSWindow* window = [metadataPanel window];
	
	if ([window isVisible])
	{
		[window performClose:sender];
	}
	else
	{
		[metadataPanel showWindow:nil];
		[metadataPanel setDirEntry:[images objectAtIndex:curImage]];
	}
}

- (IBAction)pan:(id)sender
{
	int tag = [sender tag];
	if (tag == 0)
	{
		[imageClip centerImage];
	}
	else if (tag == 1)
	{
		[imageClip panX:0 Y:50];
	}
	else if (tag == 2)
	{
		[imageClip panX:0 Y:-50];
	}
	else if (tag == 3)
	{
		[imageClip panX:-50 Y:0];
	}
	else if (tag == 4)
	{
		[imageClip panX:50 Y:0];
	}
}

// slideshow delay
- (IBAction)slideshowDelay:(id)sender
{
	int delay = [prefsGet(PrefSlideshowDelay) intValue];
	
	[slideshowDelay setIntValue:delay];
	[slideshowDelayStep setIntValue:delay];
	
	NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
	[fmt setAllowsFloats:NO];
	[fmt setMinimum:[NSNumber numberWithInt:1]];
	[fmt setMaximum:[NSNumber numberWithInt:600]];
	[slideshowDelay setFormatter:fmt];
	
	[NSApp beginSheet: slideshowDelaySheet modalForWindow:viewerWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)slideshowDelayFinished:(id)sender
{
	if ([sender tag] > 0)
	{
		prefsSet(PrefSlideshowDelay, [NSNumber numberWithInt: [slideshowDelay intValue]]);
		
		if ([self slideshowRunning])
		{
			[self slideshow:sender];
			[self slideshow:sender];
		}
	}
	
	[slideshowDelaySheet orderOut:sender];
	[NSApp endSheet:slideshowDelaySheet returnCode:[sender tag]];	
}

- (IBAction)slideshowDelayStepped:(id)sender
{
	[slideshowDelay setIntValue: [slideshowDelayStep intValue]];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[slideshowDelayStep setIntValue:[slideshowDelay intValue]];
}

// goto image
- (IBAction)gotoImage:(id)sender
{
	NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
	[fmt setAllowsFloats:NO];
	[fmt setMinimum:[NSNumber numberWithInt:1]];
	[fmt setMaximum:[NSNumber numberWithInt:[images count]]];
	[gotoImageNumber setFormatter:fmt];
	[gotoImageNumber setIntValue:curImage + 1];
	
	[gotoImageMax setStringValue:[NSString stringWithFormat:@"of %d.", [images count]]];
	
	[NSApp beginSheet: gotoImageSheet modalForWindow:viewerWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)gotoImageFinished:(id)sender
{
	if ([sender tag] > 0)
	{
		[self viewImage: [gotoImageNumber intValue] - 1];
	}
	[gotoImageSheet orderOut:sender];
	[NSApp endSheet:gotoImageSheet returnCode:[sender tag]];		
}

// image list
- (id)tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
	return [[images objectAtIndex:rowIndex] displayName];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [images count];
}

- (IBAction)toggleDrawer:(id)sender
{
	[imageListDrawer toggle:sender];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int row = [imageList selectedRow];
	if (row != -1 && curImage != -1)
		[self viewImage:row];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (void)drawerDidOpen:(NSNotification*)notification
{
	prefsSet(PrefImageListOpen, [NSNumber numberWithBool:YES]);
}

- (void)drawerDidClose:(NSNotification *)notification
{
	prefsSet(PrefImageListOpen, [NSNumber numberWithBool:NO]);	
}

- (NSSize)drawerWillResizeContents:(NSDrawer*)sender toSize:(NSSize)contentSize
{
	prefsSet(PrefImageListWidth, [NSNumber numberWithInt:contentSize.width]);
	return contentSize;
}

// image clip delegate
- (void)imageClipClose:(id)param
{
	[viewerWindow performClose:self];
	
	Browser* browser = [[AppController sharedAppController] getBrowserWithId:associatedBrowser];
	if (browser)
	{
		if (curImage >= 0)
			[browser selectDirEntry:[images objectAtIndex:curImage]];
	}
	else
	{
		DirEntry* de = [images objectAtIndex:curImage];
		Browser* browser = [[Browser alloc] init];
		[browser browseToFolder:[de getParent] sender:self];
		[browser selectDirEntry:de];
	}
}

- (void)imageClipPrevious:(id)param
{
	[self previousImage:self];
}

- (void)imageClipNext:(id)param
{
	[self nextImage:self];
}

@end