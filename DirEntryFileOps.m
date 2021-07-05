//
//  DirEntryFileOps.m
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


#import "DirEntryFileOps.h"


@implementation DirEntry (DirEntryFileOps)

-(bool)moveToTrash
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSWorkspace* ws = [NSWorkspace sharedWorkspace];

    if ([self isFile])
    {
        NSString* thumb = [self thumbnailPath];

        NSInteger tag = 0;
        [ws performFileOperation:NSWorkspaceRecycleOperation source:[[self getParent] path] destination: @"" files:[NSArray arrayWithObject:[self filename]] tag:&tag];

        if (tag >= 0)
            [fm removeItemAtPath:thumb error:nil];
    }
    else
    {
        NSMutableArray* thumbs = [NSMutableArray arrayWithCapacity:10];

        NSArray* sub = [self deepGetSubItems];
        for (DirEntry* de in sub)
            [thumbs addObject: [de thumbnailPath]];
        [thumbs addObject: [self thumbnailPath]];

        NSInteger tag = 0;
        [ws performFileOperation:NSWorkspaceRecycleOperation source:[[self getParent] path] destination: @"" files:[NSArray arrayWithObject:[self filename]] tag:&tag];

        for (NSString* thumb in thumbs)
            [fm removeItemAtPath:thumb error:nil];
    }
    return YES;
}

@end
