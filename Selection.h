//
//  Selection.h
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

@class DirEntry;

@interface Selection : NSObject {
    NSArray* selectedItems;
    NSArray* selectedFiles;
    NSArray* selectedFolders;
}

+ (Selection*)selectionWith:(NSArray*)list;
- (id)initWith:(NSArray*)list;

- (BOOL)onlyOneFile;
- (DirEntry*)firstFile;

- (int)count;
- (int)countFiles;
- (int)countFolders;

- (NSArray*)selection;
- (NSArray*)selectedFiles;
- (NSArray*)selectedFolders;
- (NSArray*)expandSelection:(int)sort;
- (NSArray*)deepExpandSelection:(int)sort;

@end
