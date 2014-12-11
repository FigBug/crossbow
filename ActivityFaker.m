//
//  ActivityFaker.m
//  Crossbow
//
//  Created by Roland Rabien on 2014-12-11.
//
//

#import "ActivityFaker.h"

@implementation ActivityFaker

- (instancetype)initWithName:(NSString*)name_
{
    self = [super init];
    if (self)
    {
        name        = name_;
        assertionID = 0;
    }
    return self;
}

- (void)dealloc
{
    [self disable];
}

- (void)enable
{
    if (assertionID)
    {
        CFStringRef reasonForActivity = (__bridge CFStringRef)name;
        
        IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, reasonForActivity, &assertionID);
    }
}

- (void)disable
{
    if (assertionID)
    {
        IOPMAssertionRelease(assertionID);
        assertionID = 0;
    }
}

@end
