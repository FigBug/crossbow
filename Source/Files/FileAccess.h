//
//  FileAccess.h
//  Crossbow
//
//  Created by Roland Rabien on 2016-10-17.
//
//

#import <Foundation/Foundation.h>

@interface FileAccess : NSObject {
    NSMutableArray* urls;
}

+ (id)sharedManager;
- (void)saveAccessTo:(NSString*)path;
- (void)shutdown;

@end
