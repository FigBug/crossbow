//
//  ThumbnailBuilder.h
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


@interface ThumbnailBuilder : NSWindowController {
    IBOutlet NSImageView* lastThumb;
    IBOutlet NSButton* rebuild;
    IBOutlet NSButton* start;
    IBOutlet NSButton* cancel;

    BOOL rebuildThumb;
    NSArray* items;
    BOOL abort;
}

- (void)setItems:(NSArray*)items;

- (IBAction)start:(id)sender;
- (IBAction)done:(id)sender;

- (void)buildProc:(id)param;
- (void)showThumb:(id)param;

@end
