//
//  ImageCache.m
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


#import "ImageCache.h"
#import "DirEntry.h"


@implementation ImageCache

- (id)init
{
    if (self = [super init])
    {
        cache = [[NSMutableDictionary alloc] initWithCapacity:5];
    }
    return self;
}

- (void)dealloc
{
    [self cancelThread];

}

- (NSImage*)imageForDirEntry:(DirEntry*)de
{
    NSImage* img = nil;

    @synchronized (self)
    {
        img = [cache objectForKey:[de path]];
        if (!img)
        {
            img = [de image];
            if (img)
                [cache setObject:img forKey:[de path]];
        }
    }
    return img;
}

- (void)cancelThread
{
    if (decodeThread)
    {
        [decodeThread cancel];
        decodeThread = nil;
    }
}

- (void)cacheDirEntries:(NSArray*)list
{
    [self cancelThread];

    NSMutableDictionary* newCache = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSMutableArray* todo = [NSMutableArray arrayWithCapacity:5];

    @synchronized (self)
    {
        for (DirEntry* de in list)
        {
            NSImage* img = [cache objectForKey:[de path]];
            if (img)
                [newCache setObject:img forKey:[de path]];
            else
                [todo addObject:de];
        }
        cache = newCache;
    }
    decodeThread = [[NSThread alloc] initWithTarget:self selector:@selector(decodeProc:) object:todo];
    [decodeThread start];
}

- (void)decodeProc:(id)todo
{
    @autoreleasepool {

        for (DirEntry* de in todo)
        {
            if ([[NSThread currentThread] isCancelled])
                return;

            @autoreleasepool {

                NSImage* img = [de image];
                if (img)
                {
                    [img isValid];

                    @synchronized (self)
                    {
                        [cache setObject:img forKey:[de path]];
                    }
                }
            }
        }
    }
}

@end
