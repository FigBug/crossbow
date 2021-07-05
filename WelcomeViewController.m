//
//  ContentViewController.m
//  StatusItemPopup
//
//  Created by Roland Rabien on 06/03/13.
//  Copyright (c) 2013 Roland Rabien. All rights reserved.
//

#import "WelcomeViewController.h"

@implementation WelcomeViewController

@synthesize closeBlock;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        __weak WelcomeViewController* weakSelf = self;
        [MTSTimer nonRepeatingTimerWithTimeInterval:30.0 callingBlock:^(MTSTimer* timer)
         {
             if (weakSelf.closeBlock)
                 weakSelf.closeBlock();
         }];
    }
    
    return self;
}

- (IBAction)closeButtonPressed:(id)sender
{
    if (closeBlock)
        closeBlock();
}

@end
