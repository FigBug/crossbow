//
//  ImageView.m
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


#import "ImageView.h"
#import "ImageClip.h"
#import "NSImageAdditions.h"

@implementation ImageView

- (id)initWithFrame:(NSRect)frame 
{
    if (self = [super initWithFrame:frame]) 
	{
		angle = 0;
		zoom  = 1;
    }
    return self;
}

- (void)drawRect:(NSRect)rect 
{
	if (opaque)
		[[NSColor whiteColor] drawSwatchInRect:rect];
	else
		[[NSColor blackColor] drawSwatchInRect:rect];
	
	if (angle)
		[[self transformWithRotationInDegrees:angle] concat];
	
	if (![self inLiveResize])
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	if (angle == 90 || angle == 270)
	{
		NSRect bounds = [self bounds];
		[image drawInRect:NSMakeRect(bounds.origin.y, bounds.origin.x, bounds.size.height, bounds.size.width) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	}
	else
	{
		[image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
}

- (void)setOpaque:(BOOL)val
{
	opaque = val;
}

- (NSSize)originalSize
{
	if (angle == 90 || angle == 270)
		return NSMakeSize(originalSize.height, originalSize.width);
	else
		return originalSize;
}

- (void)setImage:(NSImage*)img rotationAngle:(int)angle_
{
	[image release];
	
	image = [img retain];
	originalSize = [image sizeLargestRepresentation];
	
	angle = angle_;
	
	[self updateSize];
	[self setNeedsDisplay:YES];
}

- (void)setZoom:(double)zoom_
{
	if (zoom_ >= 0.01 && zoom_ <= 100.0)
	{
		zoom = zoom_;
		
		[self updateSize];	
		[self setNeedsDisplay:YES];
	}
}

- (int)angle
{
	return angle;
}

- (void)setAngle:(int)angle_
{
	angle = angle_;
	
	[self updateSize];
	[self setNeedsDisplay:YES];
}

- (void)updateSize
{
	if (image)
	{
		NSSize o = [self originalSize];
		NSSize sz = NSMakeSize(o.width * zoom, o.height * zoom);
		
		[self setFrameSize:sz];		
		[(ImageClip*)[self superview] update];
	}
}

- (NSAffineTransform*)transformWithRotationInDegrees:(int)val
{
    NSAffineTransform *rotateTF = [NSAffineTransform transform];
	
	NSSize o  = [self originalSize];
	NSSize sz = NSMakeSize(o.width * zoom, o.height * zoom);	
	
    NSPoint centerPoint = NSMakePoint(sz.width / 2, sz.height / 2);
	
	[rotateTF translateXBy: centerPoint.x yBy: centerPoint.y];
    [rotateTF rotateByDegrees: angle];
	if (angle == 90 || angle == 270)
		[rotateTF translateXBy: -centerPoint.y yBy: -centerPoint.x];
	else
		[rotateTF translateXBy: -centerPoint.x yBy: -centerPoint.y];
    return rotateTF;
}

- (BOOL)isOpaque
{
	return YES;
}

@end
