//
//  ImageClip.m
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


#import "ImageClip.h"
#import "ImageView.h"
#import "Viewer.h"

@interface NSEvent (DeviceDelta)
- (float)deviceDeltaY;
@end

@implementation ImageClip

@synthesize lastScroll;

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        center = NSMakePoint(500, 500);
        self.lastScroll = [NSDate distantPast];
    }
    return self;
}


- (void)setDelegate:(id)del
{
    delegate = del;
}

- (void)drawRect:(NSRect)rect
{
    [[NSColor blackColor] drawSwatchInRect:rect];
}

- (void)setDocument:(NSView*)view
{

    document = view;

    [self setSubviews:[NSArray arrayWithObject:document]];
}

- (void)centerImage
{
    center = NSMakePoint(500, 500);
    [self update];
}

- (NSPoint)normalizedCenter
{
    NSSize sz = [document frame].size;
    return NSMakePoint(center.x / 1000 * sz.width, center.y / 1000 * sz.height);
}

- (void)update
{
    NSRect rc = [document frame];
    NSRect bounds = [self bounds];
    NSPoint nCenter = [self normalizedCenter];

    rc.origin.x = -(nCenter.x - bounds.size.width / 2.0);
    rc.origin.y = -(nCenter.y - bounds.size.height / 2.0);

    [document setFrame:rc];
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    [self update];
}

- (void)setFrameOrigin:(NSPoint)newOrigin
{
    [super setFrameOrigin:newOrigin];
    [self update];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self update];
}

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

// The image view while it is in crop mode, otherwise nil
- (ImageView*)cropView
{
    if ([document isKindOfClass:[ImageView class]] && [(ImageView*)document cropping])
        return (ImageView*)document;
    return nil;
}

static NSPoint clampToBounds(NSPoint p, NSRect b)
{
    p.x = MIN(MAX(p.x, NSMinX(b)), NSMaxX(b));
    p.y = MIN(MAX(p.y, NSMinY(b)), NSMaxY(b));
    return p;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent*)event
{
    if ([self cropView])
    {
        unsigned short key = [event keyCode];
        if (key == 36 || key == 76)         // Return, Enter
        {
            [delegate imageClipApplyCrop:self];
            return;
        }
        if (key == 53)                      // Escape
        {
            [delegate imageClipCancelCrop:self];
            return;
        }
    }
    [super keyDown:event];
}

- (void)mouseDown:(NSEvent*)event
{
    ImageView* crop = [self cropView];
    if (crop)
    {
        cropStart = clampToBounds([crop convertPoint:[event locationInWindow] fromView:nil], [crop bounds]);
        [crop setCropRect:NSZeroRect];
        return;
    }

    if ([event clickCount] == 2)
    {
        [delegate imageClipClose:self];
    }
    else
    {
        dragStart = [event locationInWindow];
        dragCenter = center;
    }
}

- (void)panX:(int)deltaX Y:(int)deltaY
{
    NSRect rc = [document frame];

    center.x = center.x + deltaX / rc.size.width  * 1000;
    center.y = center.y + deltaY / rc.size.height * 1000;

    if (center.y < 0) center.y = 0;
    if (center.x < 0) center.x = 0;

    if (center.x > 1000) center.x = 1000;
    if (center.y > 1000) center.y = 1000;

    [self update];
}

- (void)rightMouseDown:(NSEvent*)event
{
    if ([delegate respondsToSelector:@selector(imageClipShowContextMenu:)])
        [delegate imageClipShowContextMenu:event];
}

- (void)mouseDragged:(NSEvent*)event
{
    ImageView* crop = [self cropView];
    if (crop)
    {
        NSPoint p = clampToBounds([crop convertPoint:[event locationInWindow] fromView:nil], [crop bounds]);
        [crop setCropRect:NSMakeRect(MIN(p.x, cropStart.x), MIN(p.y, cropStart.y), fabs(p.x - cropStart.x), fabs(p.y - cropStart.y))];
        return;
    }

    NSPoint dragNow = [event locationInWindow];

    NSRect rc = [document frame];

    double deltaX = dragStart.x - dragNow.x;
    center.x = dragCenter.x + deltaX / rc.size.width * 1000;

    double deltaY = dragStart.y - dragNow.y;
    center.y = dragCenter.y + deltaY / rc.size.height * 1000;

    if (center.y < 0) center.y = 0;
    if (center.x < 0) center.x = 0;

    if (center.x > 1000) center.x = 1000;
    if (center.y > 1000) center.y = 1000;

    [self update];
}

- (void)mouseUp:(NSEvent*)event
{
}

- (void)scrollWheel:(NSEvent*)event
{
    NSTimeInterval diff = [lastScroll timeIntervalSinceNow];
    if (diff < -0.3)
    {
        float delta = [event deviceDeltaY];
        if (delta > 0)
            [delegate imageClipPrevious:self];
        else if (delta < 0)
            [delegate imageClipNext:self];

        self.lastScroll = [NSDate date];
    }
}

- (BOOL)isOpaque
{
    return YES;
}

@end
