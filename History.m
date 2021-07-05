//
//  History.m
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


#import "History.h"
#import "DirEntry.h"

@implementation History

- (id)init
{
    if (self = [super init])
    {
        history = [[NSMutableArray alloc] initWithCapacity: 10];
        pos     = -1;
        max     = 30;
    }
    return self;
}

- (DirEntry*)current
{
    return [history objectAtIndex: pos];
}

- (void)add:(DirEntry*)folder
{
    if (folder)
    {
        while (pos < [history count] - 1)
            [history removeLastObject];

        [history addObject:folder];
        pos++;
    }
}

- (BOOL)canGoBack
{
    return pos > 0;
}

- (void)goBack
{
    pos--;
}

- (BOOL)canGoForward
{
    return pos < [history count] - 1;
}

- (void)goForward
{
    pos++;
}

- (BOOL)canGoUp
{
    DirEntry* de = [self current];
    return ![de isFilesystemRoot];
}

- (void)goUp
{
    [self add: [[self current] getParent]];
}

- (NSArray*)getHistory
{
    return history;
}

- (void)goToPast:(int)index
{
    pos = index;
}


@end
