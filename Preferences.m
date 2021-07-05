//
//  Preferences.m
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


#import "Preferences.h"
#import "DirEntry.h"
#import "AppController.h"

NSString* PrefStartupFolder  = @"PrefStarupFolder";
NSString* PrefBookmarks      = @"PrefBookmarks";
NSString* PrefRecentFiles    = @"PrefRecentFiles";
NSString* PrefGotoFolder     = @"PrefGotoFolder";
NSString* PrefSlideshowDelay = @"PrefSlideshowDelay";
NSString* PrefImageListOpen  = @"PrefImageListOpen";
NSString* PrefImageListWidth = @"PrefImageListWidth";
NSString* PrefZoomMode       = @"PrefZoomMode";
NSString* PrefThumbnailSize  = @"PrefThumbnailSize";
NSString* PrefRebuildThumbs  = @"PrefRebuildThumbs";
NSString* PrefShareTab       = @"PrefShareTab";
NSString* PrefSmugmugUser    = @"PrefSmugmugUser";
NSString* PrefSmugmugPass    = @"PrefSmugmugPass";
NSString* PrefRootPaths      = @"PrefRootPaths";
NSString* PrefSavedUrls      = @"PrefSavedUrls";

id prefsGet(NSString* key)
{
    return [[NSUserDefaults standardUserDefaults] objectForKey: key];
}

void prefsSet(NSString* key, id val)
{
    [[NSUserDefaults standardUserDefaults] setObject:val forKey: key];
}

@implementation Preferences

- (id)init
{
    if (self = [super init])
    {
        NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];

        NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];

        [defaultValues setObject: [NSNumber numberWithInt:0] forKey:PrefShareTab];
        [defaultValues setObject: @"" forKey:PrefSmugmugUser];
        [defaultValues setObject: @"" forKey:PrefSmugmugPass];
        [defaultValues setObject: [NSNumber numberWithBool:NO] forKey:PrefRebuildThumbs];
        [defaultValues setObject: [NSNumber numberWithDouble:0.309133] forKey: PrefThumbnailSize];
        [defaultValues setObject: [NSNumber numberWithInt:0] forKey: PrefZoomMode];
        [defaultValues setObject: @"" forKey: PrefGotoFolder];
        [defaultValues setObject: [NSNumber numberWithBool:NO] forKey: PrefImageListOpen];
        [defaultValues setObject: [NSNumber numberWithInt:175] forKey: PrefImageListWidth];
        [defaultValues setObject: [NSNumber numberWithInt:5] forKey: PrefSlideshowDelay];
        [defaultValues setObject: [[DirEntry getDesktop] path] forKey: PrefStartupFolder];
        [defaultValues setObject: [NSArray array] forKey: PrefRecentFiles];
        [defaultValues setObject: [NSArray arrayWithObjects: [[DirEntry getDesktop] path],
                                                             [[DirEntry getDownloads] path],
                                                             nil] forKey: PrefBookmarks];

        [prefs registerDefaults: defaultValues];
    }
    return self;
}

+ (id)get:(NSString*)key
{
    return [[NSUserDefaults standardUserDefaults] objectForKey: key];
}

+ (void)set:(NSString*)key withValue:(id)val
{
    [[NSUserDefaults standardUserDefaults] setObject:val forKey: key];
}

@end
