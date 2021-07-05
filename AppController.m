//
//  AppController.m
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


#import "AppController.h"
#import "Browser.h"
#import "Viewer.h"
#import "DirEntry.h"
#import "Preferences.h"
#import "PreferencesController.h"
#import "SCEvents.h"
#import "SCEvent.h"
#import "Util.h"
#import "Metadata.h"
#import "FileAccess.h"

NSString* NotThumbnailsDeleted = @"NotThumbnailsDeleted";

AppController* appController;

@implementation AppController

- (id)init
{
    if (self = [super init])
    {
        appController = self;

        preferences = [[Preferences alloc] init];

        fileSysWatch = [SCEvents sharedPathWatcher];
        [fileSysWatch setDelegate:self];
        [fileSysWatch setIgnoreEeventsFromSubDirs:YES];

        pathWatchers = [[NSMutableArray alloc] initWithCapacity:10];
        activeBrowsers = [[NSMutableArray alloc] initWithCapacity:10];

        [FileAccess sharedManager];
    }
    return self;
}


+ (AppController*)sharedAppController
{
    return appController;
}

- (NSMenu*)defaultMainMenu
{
    return menu;
}

- (Preferences*)preferences
{
    return preferences;
}

- (Metadata*)metadataPanel:(BOOL)create
{
    if (create && !metadataPanel)
        metadataPanel = [[Metadata alloc] init];
    return metadataPanel;
}

- (void)metadataPanelClosed
{
    metadataPanel = nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[FileAccess sharedManager] shutdown];
}

- (BOOL)panel:(id)sender shouldShowFilename:(NSString*)filename
{
    BOOL dir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&dir])
    {
        if (dir)
        {
            return YES;
        }
        else
        {
            NSError* error;
            NSString* filetype = [[NSWorkspace sharedWorkspace] typeOfFile:filename error: &error];

            return [[DirEntry imageUTIs] containsObject: filetype];
        }
    }
    return NO;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
    [self newBrowser:self];
    return YES;
}

- (IBAction)newBrowser:(id)sender
{
    (void)[[Browser alloc] init];
}

- (IBAction)newViewer:(id)sender
{
    (void)[[Viewer alloc] init:nil atIndex:0];
}

- (IBAction)onlineHelp:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://www.socalabs.com/help-crossbow.html"]];
}

- (IBAction)openDocument:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    [open setDelegate:self];
    [open setCanChooseFiles: YES];
    [open setCanChooseDirectories: NO];
    [open setResolvesAliases: YES];
    [open setAllowsMultipleSelection: YES];

    if ([open runModal] == NSOKButton)
    {
        NSMutableArray* files = [NSMutableArray arrayWithCapacity: 10];
        NSMutableArray* recent = [NSMutableArray arrayWithCapacity: 10];
        [recent addObjectsFromArray: prefsGet(PrefRecentFiles)];

        for (NSURL* url in [open URLs])
        {
            NSString* file = [url path];

            [[FileAccess sharedManager] saveAccessTo:file];

            [files addObject: [DirEntry dirEntryWithPath: file]];
            if ([recent containsObject:file])
                [recent removeObject:file];
            [recent addObject: file];
        }
        while ([recent count] > 10)
            [recent removeObjectAtIndex: 0];

        prefsSet(PrefRecentFiles, recent);

        (void)[[Viewer alloc] init:files atIndex:0];
    }
}

- (IBAction)showPrefs:(id)sender
{
    if (!preferencesController)
        preferencesController = [[PreferencesController alloc] init];

    [preferencesController showWindow:nil];
}

- (IBAction)clearRecentDocuments:(id)sender
{
    prefsSet(PrefRecentFiles, [NSArray array]);
}

- (IBAction)openRecent:(id)sender
{
    NSMenuItem* item = (NSMenuItem*)sender;
    NSArray* files = prefsGet(PrefRecentFiles);
    (void)[[Viewer alloc] init: [NSArray arrayWithObject:[DirEntry dirEntryWithPath:[files objectAtIndex:[item tag]]]] atIndex:0];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    NSArray* items = [[[[DirEntry dirEntryWithPath:filename] getParent] getSubFiles] sortedArrayUsingFunction:sortFunc context:(void*)BSName];
    (void)[[Viewer alloc] init: items atIndex:(int)[items indexOfObject:[DirEntry dirEntryWithPath:filename]]];

    [[FileAccess sharedManager] saveAccessTo:filename];

    return YES;
}

- (BOOL)application:(NSApplication *)theApplication openTempFile:(NSString *)filename
{
    (void)[[Viewer alloc] init: [NSArray arrayWithObject:[DirEntry dirEntryWithPath:filename]] atIndex:0];
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    if ([filenames count] == 1)
    {
        [self application:NSApp openFile:[filenames objectAtIndex:0]];

        [[FileAccess sharedManager] saveAccessTo:[filenames objectAtIndex:0]];
    }
    else
    {
        NSMutableArray* items = [NSMutableArray arrayWithCapacity:[filenames count]];
        for (NSString* filename in filenames)
        {
            [items addObject: [DirEntry dirEntryWithPath:filename]];
            [[FileAccess sharedManager] saveAccessTo:filename];
        }

        (void)[[Viewer alloc] init: items atIndex:0];
    }
    [NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (void)watchPathWith:(Browser*)watcher addOrUpdate:(BOOL)update;
{
    if (update)
    {
        if (![pathWatchers containsObject:watcher])
            [pathWatchers addObject:watcher];
    }
    else
    {
        [pathWatchers removeObject:watcher];
    }
    NSMutableArray* paths = [NSMutableArray arrayWithCapacity:10];
    for (Browser* b in pathWatchers)
        [paths addObject:[[b currentLocation] path]];

    if ([fileSysWatch isWatchingPaths])
        [fileSysWatch stopWatchingPaths];

    if ([paths count] > 0)
        [fileSysWatch startWatchingPaths:paths];
}

- (void)pathWatcher:(SCEvents*)pathWatcher eventOccurred:(SCEvent*)event
{
    for (Browser* b in pathWatchers)
    {
        if ([[[b currentLocation] path] isEqual: [event eventPath]])
            [b refreshLocation];
    }
}

- (void)registerBrowser:(Browser*)browser
{
    [activeBrowsers addObject:browser];
}

- (void)unregisterBrowser:(Browser*)browser
{
    [activeBrowsers removeObject:browser];
}

- (Browser*)getBrowserWithId:(int)browserId
{
    for (Browser* browser in activeBrowsers)
    {
        if (browser.browserId == browserId)
            return browser;
    }
    return nil;
}

- (IBAction)contactSupport:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"https://rabiensoftware.freshdesk.com/support/tickets/new"]];
}

- (IBAction)requestFeature:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"https://rabiensoftware.freshdesk.com/support/discussions/forums/19000161597"]];
}

@end
