//
//  Preferences.h
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

extern NSString* PrefStartupFolder;
extern NSString* PrefBookmarks;
extern NSString* PrefRecentFiles;
extern NSString* PrefGotoFolder;
extern NSString* PrefThumbnailSize;

extern NSString* PrefSlideshowDelay;
extern NSString* PrefImageListOpen;
extern NSString* PrefImageListWidth;
extern NSString* PrefZoomMode;

extern NSString* PrefRebuildThumbs;

extern NSString* PrefShareTab;

extern NSString* PrefSmugmugUser;
extern NSString* PrefSmugmugPass;

id prefsGet(NSString* key);
void prefsSet(NSString* key, id val);

@interface Preferences : NSObject {
	NSUserDefaults* prefs;
}

- (id)init;

- (id)get:(NSString*)key;
- (void)set:(NSString*)key withValue:(id)val;

@end
