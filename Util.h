//
//  Util.h
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


#import <Cocoa/Cocoa.h>

enum BrowserSort
{
    BSName,
    BSModified,
    BSCreated,
    BSSize,
    BSKind,
};

BOOL isVisiblePath(NSString* path);

NSString* expandIfLink(NSString* path);
NSString* fixPathCase(NSString* path);

NSString* stringFromFileSize(long long theSize);

void setMenuDelegates(NSMenu* menu, id del, NSArray* menus);

NSInteger sortFunc(id num1, id num2, void *context);

NSString* md5(NSString* str);

void addAppsToMenu(NSURL* file, NSMenu* menu, SEL sel, BOOL edit);
void openWithApp(NSURL* file, int idx, BOOL edit);

NSSize shrinkSizeToFit(NSSize rect, NSSize bounds);
NSRect shrinkRectToFit(NSRect rect, NSRect bounds);
