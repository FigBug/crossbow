#import <Cocoa/Cocoa.h>

@interface SegmentedToolbarItem : NSToolbarItem
{
	NSSegmentedControl *control;
	NSMenu *menu;
	SEL *actions;
	id targets;
}

+ (SegmentedToolbarItem*)itemWithIdentifier:(NSString*)identifier label:(NSString*)label paletteLabel:(NSString*)pallabel segments:(int)segments;

- (id)initWithItemIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments;
- (void)dealloc;

- (void)validate;

- (void)setSegment:(int)segment label:(NSString *)label image:(NSImage *)image longLabel:(NSString *)longlabel width:(int)width target:(id)target action:(SEL)action;
- (void)setSegment:(int)segment label:(NSString *)label longLabel:(NSString *)longlabel target:(id)target action:(SEL)action;
- (void)setSegment:(int)segment imageName:(NSString *)imagename longLabel:(NSString *)longlabel target:(id)target action:(SEL)action;
- (void)setupView;

- (void)clicked:(id)sender;

@end

@interface ToolItem : SegmentedToolbarItem
{
	SEL sel;
}

+ (SegmentedToolbarItem*)itemWithIdentifier:(NSString*)identifier label:(NSString*)label paletteLabel:(NSString*)pallabel imageName:(NSString*)imagename longLabel:(NSString*)longlabel action:(SEL)action activeSelector:(SEL)activeselector target:(id)activetarget;

-(id)initWithItemIdentifier:(NSString*)identifier label:(NSString*)label paletteLabel:(NSString*)pallabel imageName:(NSString*)imagename longLabel:(NSString*)longlabel action:(SEL)action activeSelector:(SEL)activeselector target:(id)activetarget;
-(void)validate;

@end

