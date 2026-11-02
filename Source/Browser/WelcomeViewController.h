//
//  ContentViewController.h
//  StatusItemPopup
//
//  Created by Roland Rabien on 06/03/13.
//  Copyright (c) 2013 Roland Rabien. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WelcomeViewController : NSViewController {
    IBOutlet NSButton* dontShowAgain;
}

@property (nonatomic, copy) void (^closeBlock)(void);

- (IBAction)closeButtonPressed:(id)sender;

@end
