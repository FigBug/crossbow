//
//  Browser.m
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


#import "Browser.h"
#import "DirEntry.h"
#import "DirEntryFileOps.h"
#import "BrowserTree.h"
#import "BrowserList.h"
#import "History.h"
#import "AppController.h"
#import "Bookmarks.h"
#import "Util.h"
#import "Viewer.h"
#import "Preferences.h"
#import "FileListItem.h"
#import "SegmentedToolbarItem.h"
#import "ImagePreview.h"
#import "Metadata.h"
#import "ThumbnailBuilder.h"
#import "ShareController.h"
#import "ZipWriter.h"
#import "ProgressSheet.h"

@implementation Browser

@synthesize folderContents;
@synthesize selection;
@synthesize folderTree;
@synthesize fileList;
@synthesize browserId;
@synthesize fileListItems;
@synthesize fileListContext;

int nextBrowserId = 1;

- (id)init
{
	if (self = [super initWithWindowNibName:@"Browser" owner:self])
	{
		browserTree = [[BrowserTree alloc] init:self];
		browserList = [[BrowserList alloc] init:self];
		fileListItems = [[NSMutableDictionary alloc] initWithCapacity:100];
		
		history = [[History alloc] init];
		bookmarks = [[Bookmarks alloc] init];
				
		sort = BSName;
	
		browserId = nextBrowserId++;
		
		[self showWindow:self];
	}
	return self;
}


- (BOOL)isEqual:(id)anObject
{	
	Browser* b = (Browser*)anObject;
	return browserId == b.browserId;
}

- (NSUInteger)hash
{
	return browserId;
}

- (void)awakeFromNib
{
	NSTableColumn* col = [folderTree outlineTableColumn];
	[col setDataCell: [[NSBrowserCell alloc] init]];
	
	// setup toolbar
	NSToolbar *toolbar= [[NSToolbar alloc] initWithIdentifier:@"BrowserToolbar"];
	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[self setupToolbarItems];
	[browserWindow setToolbar:toolbar];	
	
	NSRect rc = [thumbProgress frame];
	rc.origin.y += 4;
	rc.size.height -= 8;
	[thumbProgress setFrame:rc];
	
	[fileList setZoomValue:[prefsGet(PrefThumbnailSize) doubleValue]];
	
	[thumbSize setKnobThickness:2];
	[thumbSize setDoubleValue: [fileList zoomValue]];
	[[thumbSize cell] setControlSize:NSMiniControlSize];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thumbnailsDeleted:) name:NotThumbnailsDeleted object:nil];
}

- (void)windowDidLoad
{	
	[fileList setDataSource: browserList];
	[fileList setDelegate: browserList];
	
	[folderTree setDataSource: browserTree];
	[folderTree setDelegate: browserTree];
	
	[folderTree reloadData];	
	[self browseToFolder: [DirEntry dirEntryWithPath: prefsGet(PrefStartupFolder)] sender:self];
	
	[browserWindow makeKeyAndOrderFront:self];
	
	[[AppController sharedAppController] registerBrowser:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[AppController sharedAppController] unregisterBrowser:self];
	
	NSMenu* browserMenu = [[AppController sharedAppController] defaultMainMenu];
	setMenuDelegates(browserMenu, nil, [NSArray arrayWithObjects: @"File", @"Open Recent", @"Arrange By", @"Recent", @"Go", @"Open in Editor", @"Open in Viewer", nil]);
	[[NSApplication sharedApplication] setMainMenu: browserMenu];
	
	[[AppController sharedAppController] watchPathWith:self addOrUpdate:NO];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[browserTree cancelArrowThread];
	[self cancelThumbnailThread];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu* browserMenu = [[AppController sharedAppController] defaultMainMenu];
	setMenuDelegates(browserMenu, self, [NSArray arrayWithObjects: @"File", @"Open Recent", @"Arrange By", @"Recent", @"Go", @"Open in Editor", @"Open in Viewer", nil]);
	
	[[NSApplication sharedApplication] setMainMenu: browserMenu];
	
	Metadata* metadataPanel = [[AppController sharedAppController] metadataPanel:NO];
	if (metadataPanel)
		[metadataPanel setDirEntry:[selection firstFile]];	
	
	if (!thumbnailThread && self.folderContents && [self.folderContents count] > 0)
	{
		thumbnailThread = [[NSThread alloc] initWithTarget:self selector:@selector(thumbailProc:) object:self.folderContents];
		[thumbnailThread start];
	}
}

- (void)sheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)context
{
    if (builder && builder.window == sheet)
    {
        builder = nil;
    }
	if (code == 99)
	{
		[fileListItems removeAllObjects];
		[self refreshLocation];
	}
}

- (id)viewImages:(NSArray*)images atIndex:(int)idx
{
	id viewer = [[Viewer alloc] init:images atIndex:idx];
	[viewer setAssociatedBrowser:browserId];
	
	[self cancelThumbnailThread];
	
	return viewer;
}

- (void)selectionChanged
{
	NSIndexSet* indexes = [fileList selectionIndexes];
	self.selection = [Selection selectionWith: [self.folderContents objectsAtIndexes: indexes]];

	if ([[self selection] countFiles] >= 1)
		[self previewFile: [[self.selection selectedFiles] objectAtIndex:0]];
	else
		[self previewFile: nil];
	
	Metadata* metadataPanel = [[AppController sharedAppController] metadataPanel:NO];
	if (metadataPanel)
		[metadataPanel setDirEntry:[selection firstFile]];
	
	[self updateStatusBar];	
}

- (void)selectDirEntry:(DirEntry*)de
{
	NSInteger idx = [folderContents indexOfObject:de];
	if (idx != NSNotFound)
	{
		[fileList scrollIndexToVisible:idx];
		[fileList setSelectionIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];	
	}
}

- (void)browseToFolder:(DirEntry*)folder sender:(id)sender
{
	if ([folder isLink])
		folder = [folder getLinkedDirEntry];
		
	if (sender != history)
		[history add:folder];
	
	if (sender != folderTree)
		[browserTree selectDirEntry:[history current]];
	
	[fileListItems removeAllObjects];
	[self refreshLocation];
	[fileList scrollIndexToVisible:0];
	
	[[AppController sharedAppController] watchPathWith:self addOrUpdate:YES];
}

- (DirEntry*)currentLocation
{
	return [history current];
}

- (NSArray*)allFiles
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:10];
	for (DirEntry* de in self.folderContents)
	{
		if ([de isFile])
			[arr addObject:de];
	}
	return arr;
}

- (void)refreshLocation
{
	DirEntry* folder = [history current];
	
	self.folderContents = [[folder getSubItems] sortedArrayUsingFunction:sortFunc context:(void*)(NSInteger)sort];
	
	[browserWindow setTitleWithRepresentedFilename: [folder path]];
	
	[fileList reloadData];
	
	[self selectionChanged];
	
	[browserTree cancelArrowThread];
	[self cancelThumbnailThread];
	thumbnailThread = [[NSThread alloc] initWithTarget:self selector:@selector(thumbailProc:) object:self.folderContents];
	[thumbnailThread start];
	
	[browserTree refreshCurrent];
}

- (void)cancelThumbnailThread
{
	if (thumbnailThread)
	{
		[thumbnailThread cancel];
	}
	thumbnailThread = nil;
}

- (void)thumbailProc:(id)files
{
	@autoreleasepool {
	
		for (DirEntry* de in files)
		{
			if ([[NSThread currentThread] isCancelled])
			{
				NSMutableDictionary* params = [NSMutableDictionary dictionaryWithCapacity:1];
				[params setObject:@"Cancelled" forKey:@"Status"];
				
				[self performSelectorOnMainThread:@selector(thumbnailProcCallback:) withObject:params waitUntilDone:NO];				
				
				return;
			}
			
			@autoreleasepool {
				if (![de hasThumbnail])
				{
					NSImage* thumb = [de createThumbnail];
					if (thumb)
					{
						NSMutableDictionary* params = [NSMutableDictionary dictionaryWithCapacity:1];
						[params setObject:thumb forKey:@"Thumbnail"];
						[params setObject:de    forKey:@"DirEntry"];
						
						[self performSelectorOnMainThread:@selector(thumbnailProcCallback:) withObject:params waitUntilDone:NO];
					}
				}
			}
		}
		NSMutableDictionary* params = [NSMutableDictionary dictionaryWithCapacity:1];
		[params setObject:@"Finished" forKey:@"Status"];
		
		[self performSelectorOnMainThread:@selector(thumbnailProcCallback:) withObject:params waitUntilDone:NO];	

	}
}

- (void)thumbnailProcCallback:(id)params_
{
	NSMutableDictionary* params = (NSMutableDictionary*)params_;
	
	NSString* status = [params objectForKey:@"Status"];
	if ([status isEqual:@"Finished"])
	{
		[thumbProgress setHidden:YES];
		[browserTree runArrowThread];
		
		thumbnailThread = nil;
	}
	else if ([status isEqual:@"Cancelled"])
	{
		[thumbProgress setHidden:YES];
	}
	else
	{
		DirEntry* de   = [params objectForKey:@"DirEntry"];
		NSImage* thumb = [params objectForKey:@"Thumbnail"];
		
		// cache thumbnail
		FileListItem* fli = [fileListItems objectForKey:[de path]];
		if (!fli)
		{
			fli = [FileListItem fileListItem:de];
			[fileListItems setObject:fli forKey:[de path]];
		}
		[fli setThumb:thumb];
		
		// redraw thumbnail
		NSInteger idx = [folderContents indexOfObject:de];
		if (idx != NSNotFound)
		{
			[fileList reloadData];
					
			if ([folderContents count] > 10)
				[thumbProgress setHidden:NO];
			[thumbProgress setMinValue:0];
			[thumbProgress setMaxValue:[folderContents count]];
			[thumbProgress setDoubleValue:(double)idx];
		}
	}
}

- (FileListItem*)fileListItemFor:(DirEntry*)de
{
	FileListItem* fli = [fileListItems objectForKey:[de path]];
	if (!fli)
	{
		fli = [FileListItem fileListItem:de];
		[fileListItems setObject:fli forKey:[de path]];
	}
	return fli;
}

- (void)previewFile:(DirEntry*)file
{	
	if ([file isFile])
		[previewPane previewImage:file];
	else
		[previewPane previewImage:nil];
}

- (void)updateStatusBar
{
	Selection* sel = self.selection;
	
	int files = 0;
	long long totalSz = 0;
	for (DirEntry* de in self.folderContents)
	{
		if ([de isFile])
		{
			files++;
			totalSz += [de size];
		}
	}
	
	NSString* seg1 = [NSString stringWithFormat: @"Tolal %d files (%@)", files, stringFromFileSize(totalSz)];
	
	NSString* seg2 = nil;
	
	if ([sel countFiles] == 1 && [sel countFolders] == 0)
	{
		DirEntry* de = [[sel selectedFiles] objectAtIndex: 0];
		seg2 = [NSString stringWithFormat: @"%@, %@  |  %@", stringFromFileSize([de size]), [[de created] descriptionWithCalendarFormat:@"%m/%d/%Y %I:%M %p" timeZone:nil locale:[NSLocale currentLocale]], [de displayName]];
	}
	else if ([sel countFolders] == 1 && [sel countFiles] == 0)
	{
		DirEntry* de = [[sel selectedFolders] objectAtIndex: 0];
		seg2 = [de displayName];
	}
	else if ([sel countFiles] > 1)
	{
		long long sz = 0;
		for (DirEntry* de in [sel selectedFiles])
			sz += [de size];
			
		seg2 = [NSString stringWithFormat: @"Selected %d files (%@)", [sel countFiles], stringFromFileSize(sz)];
	}
		
	if (seg2)
		[statusBar setStringValue: [NSString stringWithFormat: @"%@  |  %@", seg1, seg2]];
	else
		[statusBar setStringValue: seg1];
}

- (NSToolbarItem*)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag 
{
	return [toolbaritems objectForKey:identifier];
}

- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return toolbaridentifiers;
}

- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:@"nav",@"reload",@"slideshow",NSToolbarFlexibleSpaceItemIdentifier,nil];
}

- (void)setupToolbarItems
{
	NSArray *items = [self makeToolbarItems];
	if (!items) 
		return;
	
	NSEnumerator *enumerator;
	NSToolbarItem *item;
	
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[items count]];
	enumerator = [items objectEnumerator];
	
	while (item=[enumerator nextObject]) 
		[dict setObject:item forKey:[item itemIdentifier]];
	
	toolbaritems = [NSDictionary dictionaryWithDictionary:dict];
	
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[items count]+3];
	enumerator = [items objectEnumerator];
	
	while (item = [enumerator nextObject]) 
		[array addObject:[item itemIdentifier]];
	
	[array addObject:NSToolbarSeparatorItemIdentifier];
	[array addObject:NSToolbarSpaceItemIdentifier];
	[array addObject:NSToolbarFlexibleSpaceItemIdentifier];
	
	toolbaridentifiers = [NSArray arrayWithArray:array];
}

- (NSArray*)makeToolbarItems
{
	NSMutableArray *array = [NSMutableArray array];
	
	SegmentedToolbarItem* tool;
	
    tool = [SegmentedToolbarItem itemWithIdentifier:@"nav" label:@"Navigation" paletteLabel:@"Navigation" segments:3];
	[tool setSegment:0 imageName:NSImageNameGoLeftTemplate longLabel:@"Previous" target:nil action:@selector(back:)];
	[tool setSegment:1 imageName:@"TBGoUp" longLabel:@"Up" target:nil action:@selector(up:)];
	[tool setSegment:2 imageName:NSImageNameGoRightTemplate longLabel:@"Next" target:nil action:@selector(forward:)];
	[tool setupView];
	[array addObject:tool];

    tool = [SegmentedToolbarItem itemWithIdentifier:@"slideshow" label:@"Slideshow" paletteLabel:@"Slideshow" segments:1];
	[tool setSegment:0 imageName:NSImageNameSlideshowTemplate longLabel:@"Slideshow" target:nil action:@selector(slideshow:)];
	[tool setupView];
	[array addObject:tool];	

    tool = [SegmentedToolbarItem itemWithIdentifier:@"reload" label:@"Reload" paletteLabel:@"Reload" segments:1];
	[tool setSegment:0 imageName:NSImageNameRefreshTemplate longLabel:@"Reload" target:nil action:@selector(reload:)];
	[tool setupView];
	[array addObject:tool];		
	
	return array;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	if ([[menu title] isEqual:@"File"] || [[menu title] isEqual:@"Context"])
	{
		BOOL enable = (self.selection && [self.selection countFiles] == 1);
		[[menu itemWithTitle:@"Open in Editor"] setEnabled:enable];
		[[menu itemWithTitle:@"Open in Viewer"] setEnabled:enable];
	}
	if ([[menu title] isEqual:@"Open in Editor"])
	{
		if ([self.selection countFiles] == 1)
			addAppsToMenu([[[self.selection selectedFiles] objectAtIndex:0] url], menu, @selector(openInEditor:), YES);
	}
	if ([[menu title] isEqual:@"Open in Viewer"])
	{
		if ([self.selection countFiles] == 1)
			addAppsToMenu([[[self.selection selectedFiles] objectAtIndex:0] url], menu, @selector(openInViewer:), NO);
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
	if ([[menu title] isEqual:@"Arrange By"])
	{
		for (NSMenuItem* item in [menu itemArray])
		{
			[item setState: ([item tag] == sort) ? NSOnState : NSOffState];
		}
	}
	if ([[menu title] isEqual:@"Recent"])
	{
		for (NSMenuItem* item in [menu itemArray])
			[menu removeItem: item];
		
		NSMutableArray* dupe = [NSMutableArray arrayWithCapacity:10];
		NSArray* hist = [history getHistory];
		int added = 0;
		for (int i = 0; added < 10 && i < [hist count]; i++)
		{
			int idx = [hist count] - i - 1;
			DirEntry* de = [hist objectAtIndex: idx];
			if (![dupe containsObject:de])
			{
				added++;
				[dupe addObject:de];
				
				NSMenuItem* item = [menu addItemWithTitle:[de displayName] action:@selector(recent:) keyEquivalent:@""];
				[item setTag:idx];
				
				NSImage* icon = [de icon];
				
				NSSize sz = { 17, 17 };
				[icon setSize: sz];			
				
				[item setImage: icon];			
			}
		}
	}
	if ([[menu title] isEqual:@"Go"])
	{
		NSArray* items = [menu itemArray];
		for (NSMenuItem* item in items)
		{
			if ([item tag] >= 1000)
				[menu removeItem: item];
		}
		
		NSArray* bm = [bookmarks bookmarks];
		int tag = 1000;
		for (DirEntry* de in bm)
		{
			NSMenuItem* item = [menu addItemWithTitle:[de displayName] action:@selector(bookmark:) keyEquivalent:@""];
			[item setTag: tag++];
			
			NSImage* icon = [de icon];
			
			NSSize sz = { 17, 17 };
			[icon setSize: sz];			
			
			[item setImage: icon];
		}
	}
}

- (BOOL)menuHasKeyEquivalent:(NSMenu*)menu forEvent:(NSEvent*)event target:(id*)target action:(SEL*)action
{
	if ([[event characters] isEqual:@" "])
	{
		*target = self;
		*action = @selector(viewSelection:);
		return YES;
	}
	return NO;
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
	SEL sel = [item action];
	if (sel == @selector(back:))
	{
		return [history canGoBack];
	}
	if (sel == @selector(forward:))
	{
		return [history canGoForward];
	}
	if (sel == @selector(up:))
	{
		return [history canGoUp];
	}
	if (sel == @selector(slideshow:))
	{
		return [self.selection count] > 0 || [self.folderContents count] > 0;
	}
	if (sel == @selector(revealFileInFinder:) ||
		sel == @selector(showMetadata:))
	{
		return [self.selection count] == 1;
	}
	if (sel == @selector(buildThumbnails:) ||
		sel == @selector(moveToTrash:) ||
		sel == @selector(createArchive:))
	{
		return [self.selection count] >= 1;
	}
	return YES;
}

- (IBAction)back:(id)sender
{
	if ([history canGoBack])
		[history goBack];
	
	[self browseToFolder:[history current] sender:history];	
}

- (IBAction)forward:(id)sender
{
	if ([history canGoForward])
		[history goForward];
	
	[self browseToFolder:[history current] sender:history];	
}

- (IBAction)up:(id)sender
{
	DirEntry* de = [history current];
	if ([history canGoUp])
		[history goUp];
	
	[self browseToFolder:[history current] sender:history];	
	[self selectDirEntry:de];
}

- (IBAction)bookmark:(id)sender
{
	NSMenuItem* itm = (NSMenuItem*)sender;
	int tag = [itm tag] - 1000;
	
	[self browseToFolder: [bookmarks bookmark:tag] sender:self];
}

- (IBAction)addBookmark:(id)sender
{
	[bookmarks addBookmark: [history current]];
}

- (IBAction)recent:(id)sender
{
	NSMenuItem* itm = (NSMenuItem*)sender;
	[history goToPast: [itm tag]];
	
	[self browseToFolder:[history current] sender:history];	
}

- (IBAction)slideshow:(id)sender
{
	if ([selection onlyOneFile])
	{
		NSArray* imagesToView = [self allFiles];
		
		int start = [imagesToView indexOfObject: [[selection selectedFiles] objectAtIndex:0]];
		
		[[self viewImages:imagesToView atIndex: start] slideshow:self];
	}
	else
	{
		NSArray* imgs = nil;
		if ([selection count] > 0)
			imgs = [selection expandSelection:sort];
		else
			imgs = [self allFiles];
			
		if ([imgs count] > 0)	
			[[self viewImages:imgs atIndex: 0] slideshow:self];
	}
}

- (IBAction)sort:(id)sender
{
	NSMenuItem* item = sender;
	sort = [item tag];
	[self refreshLocation];
}

- (IBAction)reload:(id)sender
{
	[self browseToFolder:[history current] sender:history];
	[browserTree refresh];
}

- (IBAction)revealFileInFinder:(id)sender
{
	DirEntry* de = [[self.selection selection] objectAtIndex:0];
	[[NSWorkspace sharedWorkspace] selectFile:[de path] inFileViewerRootedAtPath:[[de getParent] path]];
}

- (IBAction)openInViewer:(id)sender
{
	openWithApp([[[self.selection selectedFiles] objectAtIndex:0] url], [sender tag], NO);
}

- (IBAction)openInEditor:(id)sender
{
	openWithApp([[[self.selection selectedFiles] objectAtIndex:0] url], [sender tag], YES);	
}

- (IBAction)viewSelection:(id)sender
{
	if ([self.selection onlyOneFile])
	{
		NSMutableArray* files = [NSMutableArray arrayWithCapacity:100];
		for (DirEntry* de in folderContents)
		{
			if ([de isFile])
				[files addObject:de];
		}
		[self viewImages:files atIndex: [files indexOfObject:[self.selection firstFile]]];
	}
	else
	{
		NSArray* sel = [self.selection expandSelection:sort];
		NSInteger idx = 0;
		
		if (sender && [sender respondsToSelector:@selector(tag)])
		{
			[sel indexOfObject:[folderContents objectAtIndex:[sender tag]]];
			if (idx == NSNotFound) idx = 0;
		}
		
		[self viewImages:sel atIndex:idx];
	}
}

- (IBAction)deleteBookmark:(id)sender
{
	[bookmarkList removeAllItems];
	for (DirEntry* de in [bookmarks bookmarks])
		[bookmarkList addItemWithTitle:[de displayName]];
	[bookmarkList selectItemAtIndex:0];
	
	[NSApp beginSheet: deleteBookmarkSheet modalForWindow:browserWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)deleteBookmarkFinished:(id)sender
{
	if ([sender tag] > 0)
		[bookmarks deleteBookmark:[bookmarkList indexOfSelectedItem]];
	
	[deleteBookmarkSheet orderOut:sender];
	[NSApp endSheet:deleteBookmarkSheet returnCode:[sender tag]];	
}

- (IBAction)thumbnailsDeleted:(id)param
{
	NSArray* values = [fileListItems allValues];
	for (FileListItem* itm in values)
		[itm setThumb:nil];
	
	[fileListItems removeAllObjects];
	[self refreshLocation];
}

- (IBAction)gotoFolder:(id)sender
{
	[gotoFolder setStringValue: prefsGet(PrefGotoFolder)];
	[gotoFolderError setHidden:YES];
	
	[NSApp beginSheet: gotoFolderSheet modalForWindow:browserWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)gotoFolderFinished:(id)sender
{
	if ([sender tag] == 0)
	{
		[gotoFolderSheet orderOut:sender];
		[NSApp endSheet:gotoFolderSheet returnCode:[sender tag]];	
	}
	else
	{
		NSString* path = [gotoFolder stringValue];
		NSString* fixedPath = [[path stringByExpandingTildeInPath] stringByStandardizingPath];
		
		BOOL dir = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:fixedPath isDirectory:&dir] && dir)
		{
			prefsSet(PrefGotoFolder, path);
			
			DirEntry* de = [DirEntry dirEntryWithPath:fixedPath];
			if (de)
				[self browseToFolder:de sender:self];
			
			[gotoFolderSheet orderOut:sender];
			[NSApp endSheet:gotoFolderSheet returnCode:[sender tag]];	
		}
		else
		{
			[gotoFolderError setHidden:NO];
		}
	}
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
		[metadataPanel setDirEntry:[selection firstFile]];
	}
}

- (IBAction)setThumbsize:(id)sender
{
	[fileList setZoomValue: [thumbSize doubleValue]];
	prefsSet(PrefThumbnailSize, [NSNumber numberWithDouble:[fileList zoomValue]]);
}

- (IBAction)buildThumbnails:(id)sender
{
	builder = [[ThumbnailBuilder alloc] init];
	[builder setItems:[selection selection]];
	[NSApp beginSheet: [builder window] modalForWindow:browserWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)share:(id)sender
{
//	[[ShareController alloc] initWithImages:[selection expandSelection:sort]];
}

- (IBAction)createArchive:(id)sender
{	
	ProgressSheet* prog = [ProgressSheet alloc];	
	(void)[prog initWithThread:[ZipWriter createZippingThread:[self currentLocation] with:[selection deepExpandSelection:sort] forSheet:prog]];
	[NSApp beginSheet: [prog window] modalForWindow:browserWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];	
}

- (IBAction)moveToTrash:(id)sender
{
	for (DirEntry* de in [self.selection selection])
	{
		[de moveToTrash];
	}
	[self refreshLocation];
}

@end