//
//  ShareController.m
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


#import "ShareController.h"
#import "NSDictionary+BSJSONAdditions.h"
#import "Preferences.h"

@implementation ShareController

- (id)initWithImages:(NSArray*)images_
{
	if (self = [super initWithWindowNibName:@"Share" owner:self])
	{
		images = [images_ retain];
		
		[self showWindow:self];
	}
	return self;
}

- (void)dealloc
{
	[images release];
	
	[smAlbums release];
	[smCategories release];
	[smSubcategories release];
	
	[super dealloc];
}

- (void)windowDidLoad
{
	[smUsername setStringValue:prefsGet(PrefSmugmugUser)];
	[smPassword setStringValue:prefsGet(PrefSmugmugPass)];
	
	int idx = [prefsGet(PrefShareTab) intValue];
	[tabs selectTabViewItemAtIndex:idx];
	
	[[self window] center];
	[[self window] makeKeyAndOrderFront:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
	prefsSet(PrefSmugmugUser, [smUsername stringValue]);
	prefsSet(PrefSmugmugPass, [smPassword stringValue]);
	
	int idx = [tabs indexOfTabViewItem:[tabs selectedTabViewItem]];
	prefsSet(PrefShareTab, [NSNumber numberWithInt:idx]);
	
	[self autorelease];
}	

- (IBAction)finished:(id)sender
{
	[[self window] performClose:sender];
}

- (IBAction)upload:(id)sender
{
}

- (NSString *)formatType
{
	return SMUGMUG_JSON_FORMAT;
}

- (NSDictionary *)formatDictionaryFromResponseData:(NSData *)data
{	
	// create an autoreleased NSString from data
	NSMutableString *jsonString = [[[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	// fix JSON URLs
	[jsonString replaceOccurrencesOfString:@"\\/" withString:@"/" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [jsonString length])];
	
	// now, format the response
	NSDictionary *responseDictionary = [NSDictionary dictionaryWithJSONString:jsonString];
	
	return responseDictionary;
}

- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
	int tab = [[tabViewItem identifier] intValue];
	if (tab == 3 && [[smUsername stringValue] length] > 0 && [[smPassword stringValue] length] > 0)
		[NSThread detachNewThreadSelector:@selector(smugmugSync:) toTarget:self withObject:[NSArray arrayWithObjects:[smUsername stringValue], [smPassword stringValue], nil]];
}

- (void)smugmugSync:(id)param
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	CocoaSmugMug* sm = [[CocoaSmugMug alloc] initWithResponseFormatter:self];
	
	SmugMugResponse* res = [sm loginWithAPIKey:@"PslAbAcIRIwjggQ2IC7XPLv26otDgajZ" email:[param objectAtIndex:0] password:[param objectAtIndex:1]];
	if (res)
	{
		//smAlbums        = [[sm getAllAlbums] retain];
		//smCategories    = [[sm getAllCategories] retain];
		//smSubcategories = [[sm getAllSubCategories] retain];
				
		[self performSelectorOnMainThread:@selector(smugmugSyncDone:) withObject:nil waitUntilDone:NO];
	}
	
	[sm release];
	[pool release];
	
}

- (void)smugmugSyncDone:(id)param
{
}

@end
