//
//  BrowserTree.m
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


#import "BrowserTree.h"
#import "Browser.h"
#import "DirEntry.h"
#import "Util.h"
#import "Preferences.h"
#import "FileAccess.h"

NSString* const BrowserTreeRootFolderDragType = @"com.rabiensoftware.crossbow.rootfolder";

@implementation BrowserTreeSeparator
+ (instancetype)shared
{
    static BrowserTreeSeparator* separator = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ separator = [[BrowserTreeSeparator alloc] init]; });
    return separator;
}
@end

@implementation SeparatorCell
- (void)drawWithFrame:(NSRect)frame inView:(NSView*)view
{
    NSRect line = NSMakeRect(NSMinX(frame) + 4, floor(NSMidY(frame)), NSWidth(frame) - 8, 1);
    [[NSColor separatorColor] set];
    NSRectFillUsingOperation(line, NSCompositingOperationSourceOver);
}
@end

static BOOL isSeparator(id item)
{
    return item == [BrowserTreeSeparator shared];
}

@implementation BrowserTree

- (id)init:(Browser*)browser_
{
    if (self = [super init])
    {
        browser   = browser_;

        deCache = [[NSMutableSet alloc] initWithCapacity: 100];
        deSubItems = [[NSMutableDictionary alloc] initWithCapacity: 100];

        NSWorkspace* ws = [NSWorkspace sharedWorkspace];
        [[ws notificationCenter] addObserver:self selector:@selector(devicesChanged:) name:@"NSWorkspaceDidMountNotification" object:ws];
        [[ws notificationCenter] addObserver:self selector:@selector(devicesChanged:) name:@"NSWorkspaceDidUnmountNotification" object:ws];
    }
    return self;
}

- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (NSArray*)getSubFolders:(DirEntry*)de
{
    if (isSeparator(de))
        return @[];
    NSString* key = de ? [de path] : @"(null)";

    NSArray* res = [deSubItems objectForKey:key];
    if (res)
        return res;

    if (de)
    {
        res = [[de getSubFolders] sortedArrayUsingFunction:sortFunc context:(void*)BSName];
    }
    else
    {
        // The user's folders, a separator, then the mounted volumes
        NSMutableArray* roots = [[DirEntry getUserRootItems] mutableCopy];
#ifndef APPSTORE
        NSMutableArray* volumes = [[DirEntry getRootItems] mutableCopy];
        [volumes removeObjectsInArray:roots];
        if ([roots count] > 0 && [volumes count] > 0)
            [roots addObject:[BrowserTreeSeparator shared]];
        [roots addObjectsFromArray:volumes];
#endif
        res = roots;
    }

    [deSubItems setObject:res forKey:key];
    [deCache addObjectsFromArray:res];

    return res;
}

// NSOutlineView does not support a reloadData that starts while one is in
// progress, so every reload goes through here.
- (void)reloadTree
{
    if (reloading)
        return;
    reloading = YES;
    [browser.folderTree reloadData];
    reloading = NO;
}

- (void)devicesChanged:(id)param
{
    [deSubItems removeObjectForKey:@"(null)"];
    [self reloadTree];
}

- (void)refresh
{
    [deSubItems removeAllObjects];
    [self reloadTree];
}

- (void)refreshCurrent
{
    DirEntry* de = [self selectedDirEntry];
    if (!de)
        return;

    [deSubItems removeObjectForKey:[de path]];
    [browser.folderTree reloadItem:de];
}

- (void)runArrowThread
{
    [self cancelArrowThread];

    NSOutlineView* ov = browser.folderTree;
    NSMutableArray* items = [NSMutableArray arrayWithCapacity:[ov numberOfRows]];
    for (int i = 0; i < [ov numberOfRows]; i++)
        [items addObject:[ov itemAtRow:i]];

    arrowThread = [[NSThread alloc] initWithTarget:self selector:@selector(arrowProc:) object:items];
    [arrowThread start];
}

- (void)cancelArrowThread
{
    if (arrowThread)
    {
        [arrowThread cancel];
        arrowThread = nil;
    }
}

- (void)arrowProc:(id)files
{
    @autoreleasepool {

        int done = 0;
        for (DirEntry* de in files)
        {
            if ([[NSThread currentThread] isCancelled])
            {
                return;
            }
            if (![de isKindOfClass:[DirEntry class]])
                continue;

            if ([de hasSubFolders:YES] == MAYBE)
            {
                [de hasSubFolders:NO];
                done++;

                if (done % 5 == 0)
                {
                    [self performSelectorOnMainThread:@selector(arrowProcCallback:) withObject:@"working" waitUntilDone:NO];
                }
            }
        }
        [self performSelectorOnMainThread:@selector(arrowProcCallback:) withObject:@"finished" waitUntilDone:NO];

    }
}

- (void)arrowProcCallback:(id)params
{
    NSString* status = (NSString*)params;

    [self reloadTree];

    if ([status isEqual:@"finished"])
    {
        arrowThread = nil;
    }
}

- (void)selectDirEntry:(DirEntry*)de
{
    NSArray* hierarchy = [de getHierarchy];

    for (DirEntry* parentDe in hierarchy)
        [browser.folderTree expandItem:parentDe];

    int row = (int)[browser.folderTree rowForItem:de];
    if (row != -1)
    {
        [browser.folderTree selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [browser.folderTree scrollRowToVisible:row];
    }
}

- (DirEntry*)selectedDirEntry
{
    int index = (int)[browser.folderTree selectedRow];
    if (index == -1)
        return nil;

    DirEntry* de = [browser.folderTree itemAtRow:index];
    return de;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (isSeparator(item))
        return nil;
    if (item)
    {
        DirEntry* de = (DirEntry*)item;
        return [[self getSubFolders:de] objectAtIndex:index];
    }
    else
    {
        return [[self getSubFolders:nil] objectAtIndex:index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (isSeparator(item))
        return NO;
    DirEntry* de = (DirEntry*)item;
    int subFolders = [de hasSubFolders:YES];
    if (subFolders == YES || subFolders == MAYBE)
        return YES;
    else
        return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (isSeparator(item))
        return 0;
    if (item)
    {
        DirEntry* de = (DirEntry*)item;
        return [[self getSubFolders:de] count];
    }
    else
    {
        return [[self getSubFolders:nil] count];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if (item && !isSeparator(item))
    {
        DirEntry* de = (DirEntry*)item;
        return [de displayName];
    }
    return @"";
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    NSOutlineView* folderTree = [notification object];
    DirEntry* de = [folderTree itemAtRow: [folderTree selectedRow]];
    if (![de isKindOfClass:[DirEntry class]] || [de isEqual:[browser currentLocation]])
        return;

    // The view never allows an empty selection, so a reload can change the selection
    // from inside reloadData. Browsing refreshes the tree, so defer it until the
    // reload has finished rather than nesting one reload inside another.
    dispatch_async(dispatch_get_main_queue(), ^{
        DirEntry* now = [folderTree itemAtRow:[folderTree selectedRow]];
        if ([now isKindOfClass:[DirEntry class]] && ![now isEqual:[self->browser currentLocation]])
            [self->browser browseToFolder:now sender:folderTree];
    });
}

- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
    DirEntry* de = [[notification userInfo] objectForKey:@"NSObject"];
    DirEntry* sel = [self selectedDirEntry];

    if (sel && [sel isChildOf: de])
    {
        int row = (int)[browser.folderTree rowForItem:de];
        if (row != -1)
        {
            [browser.folderTree selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [browser.folderTree scrollRowToVisible:row];
        }
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if (item && !isSeparator(item) && [cell respondsToSelector:@selector(setImage:)])
    {
        NSSize sz = { 17, 17 };

        DirEntry* de = (DirEntry*)item;
        NSImage* icon = [de icon];
        [icon setSize: sz];
        [cell setImage: icon];
        [cell setLeaf:YES];
    }
}

//==============================================================================
// Separator row

- (BOOL)outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
    return !isSeparator(item);
}

- (CGFloat)outlineView:(NSOutlineView*)outlineView heightOfRowByItem:(id)item
{
    return isSeparator(item) ? 9 : [outlineView rowHeight];
}

- (NSCell*)outlineView:(NSOutlineView*)outlineView dataCellForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
    if (tableColumn && isSeparator(item))
    {
        static SeparatorCell* cell = nil;
        if (!cell)
            cell = [[SeparatorCell alloc] initTextCell:@""];
        return cell;
    }
    return [tableColumn dataCell];
}

//==============================================================================
// Drag and drop: reorder the user's folders, or add folders dropped from the Finder

- (BOOL)isUserRootItem:(id)item
{
    return [item isKindOfClass:[DirEntry class]] && [prefsGet(PrefRootPaths) containsObject:[(DirEntry*)item path]];
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView*)outlineView pasteboardWriterForItem:(id)item
{
    if (![self isUserRootItem:item])
        return nil;
    NSPasteboardItem* pbItem = [[NSPasteboardItem alloc] init];
    [pbItem setString:[(DirEntry*)item path] forType:BrowserTreeRootFolderDragType];
    return pbItem;
}

// Folder URLs on the pasteboard, or nil when it holds anything else
- (NSArray*)folderURLsOnPasteboard:(NSPasteboard*)pasteboard
{
    NSArray* urls = [pasteboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    if ([urls count] == 0)
        return nil;
    for (NSURL* url in urls)
    {
        NSNumber* isDir = nil;
        if (![url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil] || ![isDir boolValue])
            return nil;
    }
    return urls;
}

- (NSDragOperation)outlineView:(NSOutlineView*)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
    NSPasteboard* pasteboard = [info draggingPasteboard];
    BOOL reorder = [[pasteboard types] containsObject:BrowserTreeRootFolderDragType];
    if (!reorder && ![self folderURLsOnPasteboard:pasteboard])
        return NSDragOperationNone;

    // Everything lands in the user's section at the top level
    NSArray* userItems = [DirEntry getUserRootItems];
    NSInteger target;
    if (item == nil)
        target = (index == NSOutlineViewDropOnItemIndex) ? (NSInteger)[userItems count] : MIN(MAX(index, 0), (NSInteger)[userItems count]);
    else if ([self isUserRootItem:item])
        target = [userItems indexOfObject:item];
    else
        return NSDragOperationNone;

    [outlineView setDropItem:nil dropChildIndex:target];
    return reorder ? NSDragOperationMove : NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView*)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
    NSPasteboard* pasteboard = [info draggingPasteboard];
    NSArray* paths = nil;

    if ([[pasteboard types] containsObject:BrowserTreeRootFolderDragType])
    {
        NSMutableArray* moved = [NSMutableArray array];
        for (NSPasteboardItem* pbItem in [pasteboard pasteboardItems])
        {
            NSString* path = [pbItem stringForType:BrowserTreeRootFolderDragType];
            if (path)
                [moved addObject:path];
        }
        paths = moved;
    }
    else
    {
        NSMutableArray* added = [NSMutableArray array];
        for (NSURL* url in [self folderURLsOnPasteboard:pasteboard])
        {
            if (![prefsGet(PrefRootPaths) containsObject:[url path]])
                [DirEntry addDisplayRootItem:[url path]];
            [added addObject:[url path]];
        }
        paths = added;
    }
    if ([paths count] == 0)
        return NO;

    [DirEntry moveDisplayRootItems:paths toIndex:index];
    [self devicesChanged:nil];
    [self selectDirEntry:[DirEntry dirEntryWithPath:[paths objectAtIndex:0]]];
    return YES;
}

@end
