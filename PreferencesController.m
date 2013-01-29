//
//  PreferencesController.m
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


#import "PreferencesController.h"
#import "Preferences.h"
#import "AppController.h"
#import "DirEntry.h"

@implementation PreferencesController

- (id)init
{
	if (self = [super initWithWindowNibName:@"Preferences"])
	{
	}
	return self;
}

- (void)setupToolbar
{
	[self setCrossFade:YES];
	
	[self addView:general label:@"General" image:[NSImage imageNamed:@"NSPreferencesGeneral"]];
	[self addView:advanced label:@"Advanced" image:[NSImage imageNamed:@"NSAdvanced"]];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[[self window] setDelegate:self];

	// General
	[startupFolder setURL: [NSURL fileURLWithPath: prefsGet(PrefStartupFolder)]];
}

- (IBAction)startupFolderChanged:(id)sender
{
	NSPathComponentCell* cell = [startupFolder clickedPathComponentCell];
	
	NSURL* url = cell ? [cell URL] : [startupFolder URL];
	if ([url isFileURL] && [[DirEntry dirEntryWithURL: url] isFolder])	
		prefsSet(PrefStartupFolder, [url path]);
	[startupFolder setURL: [NSURL fileURLWithPath: prefsGet(PrefStartupFolder)]];
}

- (void)windowWillClose:(NSNotification *)notification
{
	prefsSet(PrefStartupFolder, [[startupFolder URL] path]);
}

- (IBAction)clearThumbnailCache:(id)sender
{
	[DirEntry clearAllThumbnails];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotThumbnailsDeleted object:self];
}


@end
