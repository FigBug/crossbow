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
            file = de;
            [NSThread detachNewThreadSelector:@selector(decodeProc:) toTarget:self withObject:[NSArray arrayWithObjects:de, img, nil]];
            return;
        }
    }
    file        = nil;
    cachedImage = nil;
    self.image  = nil;
}

- (void)decodeProc:(NSArray*)params
{
    @autoreleasepool {

        NSAssert(params.count == 2, @"params error");
        if (params.count >= 2)
        {
            DirEntry* de   = [params objectAtIndex:0];
            NSImage* image = [params objectAtIndex:1];

            NSImage* resizedImage = [image imageByScalingProportionallyToSize:NSMakeSize(512,512)];
            if (resizedImage)
                [self performSelectorOnMainThread:@selector(decodeFinished:) withObject:[NSArray arrayWithObjects:de, resizedImage, nil] waitUntilDone:NO];

            NSAssert(image != nil && resizedImage != nil, @"nil images");
        }
    }
}

- (void)decodeFinished:(NSArray*)params
{
    NSAssert(params.count == 2, @"params error");
    if (params.count >= 2)
    {
        DirEntry* de   = [params objectAtIndex:0];
        NSImage* image = [params objectAtIndex:1];

        if ([[file filetype] isEqual:@"com.adobe.pdf"])
        {
            NSImage* newImage = [[NSImage alloc] initWithSize:[image size]];
            [newImage lockFocus];
            [[NSColor whiteColor] set];
            CGRect rc = NSMakeRect(0,0,[newImage size].width, [newImage size].height);
            NSRectFill(rc);
            [image drawInRect:rc];
            [newImage unlockFocus];
            image = newImage;
        }

        if (de && file && [de isEqual:file])
        {
            self.image = image;
            cachedImage = image;
        }
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSColor* bk = [NSColor blackColor];
    [bk drawSwatchInRect:dirtyRect];

    [super drawRect:dirtyRect];
}

@end
