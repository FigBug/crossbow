//
//  FileAccess.m
//  Crossbow
//
//  Created by Roland Rabien on 2016-10-17.
//
//

#import "FileAccess.h"
#import "Preferences.h"

@implementation FileAccess

+ (id)sharedManager
{
    static FileAccess *sharedFileAccess = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedFileAccess = [[self alloc] init];
    });
    return sharedFileAccess;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self load];
    }
    return self;
}

- (void)load
{
    urls = [prefsGet(PrefSavedUrls) mutableCopy];
    
    if (urls == nil)
        urls = [NSMutableArray array];
    
    for (NSData* bookmark in urls)
    {
        NSError* err;
        BOOL isStale;

        NSURL* bookmarkUrl = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:&err];
        [bookmarkUrl startAccessingSecurityScopedResource];
    }
}

- (void)save
{
    prefsSet(PrefSavedUrls, urls);
}

- (void)saveAccessTo:(NSString*)path
{
    NSURL* fileUrl = [NSURL fileURLWithPath:path];
    
    NSError* err;
    BOOL isStale;
    
    NSData* bookmark  = [fileUrl bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&err];
    NSURL* bookmarkUrl = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:&err];
    
    [bookmarkUrl startAccessingSecurityScopedResource];
    
    [urls addObject:bookmark];
    
    [self save];
}

- (void)shutdown
{
    for (NSData* bookmark in urls)
    {
        NSError* err;
        BOOL isStale;

        NSURL* bookmarkUrl = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:&err];
        [bookmarkUrl stopAccessingSecurityScopedResource];
    }
}

@end
