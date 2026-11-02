//
//  ActivityFaker.h
//  Crossbow
//
//  Created by Roland Rabien on 2014-12-11.
//
//

#import <Foundation/Foundation.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

@interface ActivityFaker : NSObject
{
    IOPMAssertionID assertionID;
    NSString* name;
}

- (instancetype)initWithName:(NSString*)name;
- (void)dealloc;

- (void)enable;
- (void)disable;

@end
