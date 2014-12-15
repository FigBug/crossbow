//
//  ThumbnailBuilder.m
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


#import "ThumbnailBuilder.h"
#import "DirEntry.h"
#import "Preferences.h"
#import "NSImageAdditions.h"

@implementation ThumbnailBuilder

- (id)init
{
	if (self = [super initWithWindowNibName:@"ThumbnailBuilder" owner:self])
	{
	}
	return self;
}

- (void)dealloc
{
}

- (IBAction)start:(id)sender
{
	[lastThumb setEnabled:YES];
	
	[start setEnabled:NO];
	[rebuild setEnabled:NO];
	
	abort = NO;
	rebuildThumb = [rebuild state] == NSOnState;
	prefsSet(PrefRebuildThumbs, [NSNumber numberWithBool:rebuildThumb]);
	[NSThread detachNewThreadSelector:@selector(buildProc:) toTarget:self withObject:nil];
}

- (void)awakeFromNib
{
	[lastThumb setEnabled:NO];
	
	[rebuild setState: [prefsGet(PrefRebuildThumbs) boolValue] ? NSOnState : NSOffState];
}

- (void)buildProc:(id)param
{
	@autoreleasepool {
	
		NSMutableArray* imagesTodo  = [NSMutableArray arrayWithCapacity:100];
		NSMutableArray* foldersTodo = [NSMutableArray arrayWithCapacity:100];
		
		for (DirEntry* de in items)
		{
			if ([de isFolder])
				[foldersTodo addObject:de];
			else
				[imagesTodo addObject:de];
		}
		
		while (([imagesTodo count] > 0 || [foldersTodo count] > 0) && !abort)
		{
			@autoreleasepool {
			
				if ([imagesTodo count] > 0)
				{
					DirEntry* de = [imagesTodo objectAtIndex:0];
					
					if (![de hasThumbnail] || rebuildThumb)
					{
						NSImage* img = [de createThumbnail];
						
						if (img)
							[self performSelectorOnMainThread:@selector(showThumb:) withObject:img waitUntilDone:NO];
					}
					[imagesTodo removeObjectAtIndex:0];
				}
				else if ([foldersTodo count] > 0)
				{
					DirEntry* de = [foldersTodo objectAtIndex:0];
					
					if (![de hasThumbnail] || rebuildThumb)
					{
						NSImage* img = [de createThumbnail];
						
						if (img)
							[self performSelectorOnMainThread:@selector(showThumb:) withObject:img waitUntilDone:NO];
					}
							
					if (![de isLink])
					{
						NSArray* subItems = [de getSubItems];
						for (DirEntry* subDe in subItems)
						{
							if ([subDe isFolder])
								[foldersTodo addObject:subDe];
							else
								[imagesTodo addObject:subDe];
						}
					}
					[foldersTodo removeObjectAtIndex:0];
				}
			
			}
		}
		[self performSelectorOnMainThread:@selector(showThumb:) withObject:nil waitUntilDone:NO];
	}
}

- (void)showThumb:(id)param
{
	if (param)
	{
		NSRect rc = [lastThumb bounds];
		NSImage* img = [param imageCroppedToFitSize:rc.size];
		[lastThumb setImage:img];
	}
	else
	{
		[cancel setTitle:@"Close"];
	}
}

- (IBAction)done:(id)sender
{
	abort = YES;
	[[self window] orderOut:sender];
	[NSApp endSheet:[self window] returnCode:99];	
}

- (void)setItems:(NSArray*)items_
{
	items = items_;
}

@end
