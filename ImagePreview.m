//
//  ImagePreview.m
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


#import "ImagePreview.h"
#import "NSImageAdditions.h"
#import "DirEntry.h"
#import "Util.h"

@implementation ImagePreview

@synthesize cachedImage;
@synthesize file;

- (id)init
{
	if (self = [super init])
	{
	}
	return self;
}


- (void)previewImage:(DirEntry*)de
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(updateNow:) withObject:de afterDelay:0.1];
}

- (void)updateNow:(DirEntry*)de
{
	if (de && file && [de isEqual:file])
		return;
	
	if (de)
	{
		NSImage* img = [de image];
		if (img)
		{
			self.file = de;		
			[NSThread detachNewThreadSelector:@selector(decodeProc:) toTarget:self withObject:[NSArray arrayWithObjects:de, img, nil]];
			return;
		}
	}
	self.file        = nil;
	self.cachedImage = nil;
	[self setNeedsDisplay:YES];
}

- (void)decodeProc:(NSArray*)params
{
	@autoreleasepool {
	
		DirEntry* de   = [params objectAtIndex:0];
		NSImage* image = [params objectAtIndex:1];
		
		NSImage* resizedImage = [image imageByScalingProportionallyToSize:NSMakeSize(512,512)];
		resizedImage = [resizedImage rotated:[de rotationAngle]];
		[self performSelectorOnMainThread:@selector(decodeFinished:) withObject:[NSArray arrayWithObjects:de, resizedImage, nil] waitUntilDone:NO];
	
	}
}

- (void)decodeFinished:(NSArray*)params
{
	DirEntry* de   = [params objectAtIndex:0];
	NSImage* image = [params objectAtIndex:1];

	if (de && file && [de isEqual:file])
	{
		self.cachedImage = image;
		[self setNeedsDisplay:YES];
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSGraphicsContext* ctx = [NSGraphicsContext currentContext];
	
	NSColor* bk = [NSColor blackColor];
	[bk drawSwatchInRect:dirtyRect];
	
	if (cachedImage)
	{
		NSRect area = [self bounds];
		NSSize sz   = [cachedImage sizeLargestRepresentation];
	
		if ([[file filetype] isEqual:@"com.adobe.pdf"])
			[[NSColor whiteColor] drawSwatchInRect:shrinkRectToFit(NSMakeRect(0, 0, sz.width, sz.height), area)];
		
		if (sz.width < area.size.width && sz.height < area.size.height)
		{
			[cachedImage drawAtPoint:NSMakePoint((area.size.width - sz.width) / 2, (area.size.height - sz.height) / 2) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		}
		else
		{
			[ctx setImageInterpolation:NSImageInterpolationHigh];
			[cachedImage drawInRect:[self bounds] operation:NSCompositeSourceOver fraction:1.0 method:MGImageResizeScale];
		}
	}
}

@end
