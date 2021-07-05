//
//  AppController.h
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
#import "SCEventListenerProtocol.h"

@class Preferences;
@class PreferencesController;
@class SCEvents;
@class Browser;
@class Metadata;

extern NSString* NotThumbnailsDeleted;

@interface AppController : NSObject <NSApplicationDelegate, SCEventListenerProtocol, NSOpenSavePanelDelegate> {
    IBOutlet NSMenu* menu;

    Preferences* preferences;
    PreferencesController* preferencesController;
    SCEvents* fileSysWatch;
    NSMutableArray* pathWatchers;
    Metadata* metadataPanel;

    NSMutableArray* activeBrowsers;
}

+ (AppController*)sharedAppController;
- (NSMenu*)defaultMainMenu;
- (Preferences*)preferences;

- (Metadata*)metadataPanel:(BOOL)create;
- (void)metadataPanelClosed;

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename;

- (void)watchPathWith:(Browser*)watcher addOrUpdate:(BOOL)update;
- (void)pathWatcher:(SCEvents *)pathWatcher eventOccurred:(SCEvent *)event;

- (void)registerBrowser:(Browser*)browser;
- (void)unregisterBrowser:(Browser*)browser;
- (Browser*)getBrowserWithId:(int)browserId;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication;

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (BOOL)application:(NSApplication *)theApplication openTempFile:(NSString *)filename;
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames;

- (IBAction)newBrowser:(id)sender;
- (IBAction)newViewer:(id)sender;
- (IBAction)onlineHelp:(id)sender;
- (IBAction)openDocument:(id)sender;
- (IBAction)openRecent:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (IBAction)clearRecentDocuments:(id)sender;
- (IBAction)contactSupport:(id)sender;
- (IBAction)requestFeature:(id)sender;


@end
