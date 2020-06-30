#import "SegmentedToolbarItem.h"

@interface ValData : NSObject <NSValidatedUserInterfaceItem>
{
	SEL sel;
}

@property (nonatomic, assign) SEL sel;

+ (ValData*)valData:(SEL)sel;
- (SEL)action;
- (NSInteger)tag;

@end

@implementation ValData

@synthesize sel;

+ (ValData*)valData:(SEL)sel_
{
	ValData* d = [[ValData alloc] init];
	d.sel = sel_;
	return d;
}

- (SEL)action
{
	return sel;
}

- (NSInteger)tag;
{
	return 0;
}

@end


@implementation SegmentedToolbarItem

+(SegmentedToolbarItem*)itemWithIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments
{
	return [[SegmentedToolbarItem alloc] initWithItemIdentifier:identifier label:label paletteLabel:pallabel segments:segments];
}

-(id)initWithItemIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel segments:(int)segments
{
	if(self = [super initWithItemIdentifier:identifier])
	{
		[self setLabel:label];
		[self setPaletteLabel:pallabel];

		control = [[NSSegmentedControl alloc] init];
		[control setSegmentCount:segments];
		[[control cell] setTrackingMode:NSSegmentSwitchTrackingMomentary];

		if (segments != 1)
		{
			menu = [[NSMenu alloc] init];

			for (int i = 0; i < segments; i++)
				[menu addItem:[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""]];

			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:pallabel action:NULL keyEquivalent:@""];
			[item setSubmenu:menu];

			[self setMenuFormRepresentation:item];
		}
		else
		{
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
			[self setMenuFormRepresentation:item];
			menu = nil;
		}

		[control setTarget:self];
		[control setAction:@selector(clicked:)];
        
        actions = [NSMutableArray array];
        targets = [NSMutableArray array];

        for (int i = 0; i < segments; i++)
        {
            [actions addObject:[NSNull null]];
            [targets addObject:[NSNull null]];
        }
	}
	return self;
}

-(void)validate
{
	if ([[NSApplication sharedApplication] mainWindow] != [control window]) 
	{
		[self setEnabled:NO];
	}
	else
	{
		[self setEnabled:YES];

		int count = (int)[control segmentCount];
		for (int i = 0; i < count; i++)
		{
            SEL action = [actions[i] pointerValue];
            id  target = targets[i];
            if (target == [NSNull null])
                target = nil;
            
			id validator = [NSApp targetForAction:action to:target from:self];
			
			BOOL enable;
            if ((validator == nil) || ![validator respondsToSelector:action])
			{
                enable = NO;
            } 
			else if ([validator respondsToSelector:@selector(validateUserInterfaceItem:)]) 
			{
                enable = [validator validateUserInterfaceItem:[ValData valData:action]];
            } 
			else 
			{
                enable = YES;
            }
			[control setEnabled:enable forSegment:i];
		}
	}
}

-(void)setSegment:(int)segment label:(NSString *)label image:(NSImage *)image longLabel:(NSString *)longlabel width:(int)width target:(id)target action:(SEL)action
{
	if (segment < 0 || segment >= [control segmentCount]) 
		return;

	[control setLabel:label forSegment:segment];
	[control setImage:image forSegment:segment];
	[control setWidth:width forSegment:segment];
	[[control cell] setToolTip:longlabel forSegment:segment];

	actions[segment] = [NSValue valueWithPointer:action];
    targets[segment] = target ? target : [NSNull null];

	NSMenuItem *item;
	if(menu) 
		item = [menu itemAtIndex:segment];
	else 
		item = [self menuFormRepresentation];

	[item setTitle:longlabel];
	[item setImage:image];
	[item setAction:action];
}

-(void)setSegment:(int)segment label:(NSString *)label longLabel:(NSString *)longlabel target:(id)target action:(SEL)action
{
	[self setSegment:segment label:label image:nil longLabel:longlabel width:0 target:target action:action];
}

-(void)setSegment:(int)segment imageName:(NSString *)imagename longLabel:(NSString *)longlabel target:(id)target action:(SEL)action
{
	NSImage *image = [NSImage imageNamed:imagename];
	int width = [image size].width;
	if (width < 22)
		width = 22;
	
	[self setSegment:segment label:nil image:image longLabel:longlabel width:width target:target action:action];
}

-(void)setupView
{
	[control sizeToFit];
	[self setView:control];
	[self setMinSize:[control frame].size];
	[self setMaxSize:[control frame].size];
}

-(void)clicked:(id)sender
{
    id action = actions[[sender selectedSegment]];
    SEL selAction = [action pointerValue];
    
	[[NSApplication sharedApplication] sendAction:selAction to:nil from:self];
}

@end



@implementation ToolItem

+(SegmentedToolbarItem *)itemWithIdentifier:(NSString*)identifier label:(NSString*)label paletteLabel:(NSString*)pallabel imageName:(NSString*)imagename longLabel:(NSString*)longlabel action:(SEL)action activeSelector:(SEL)activeselector target:(id)activetarget
{
	return [[ToolItem alloc] initWithItemIdentifier:identifier label:label paletteLabel:pallabel imageName:imagename longLabel:longlabel action:action activeSelector:activeselector target:activetarget];
}

-(id)initWithItemIdentifier:(NSString *)identifier label:(NSString *)label paletteLabel:(NSString *)pallabel imageName:(NSString *)imagename longLabel:(NSString *)longlabel action:(SEL)action activeSelector:(SEL)activeselector target:(id)activetarget
{
	if(self = [super initWithItemIdentifier:identifier label:label paletteLabel:pallabel segments:1])
	{
		sel = activeselector;

		[[control cell] setTrackingMode:NSSegmentSwitchTrackingSelectAny];

		[self setSegment:0 imageName:imagename longLabel:longlabel target:activetarget action:action];
		[self setupView];
	}
	return self;
}

-(void)validate
{
	[super validate];
    
    id action = actions[0];
    id target = targets[0];
    
    SEL selAction = [action pointerValue];
    if (target == [NSNull null])
        target = nil;
	
    id validator = [NSApp targetForAction:selAction to:target from:self];

    BOOL active = NO;
    if (validator)
    {
        IMP imp = [validator methodForSelector:sel];
        BOOL (*func)(id, SEL) = (void*)imp;
        active = func(validator, sel);
    }

	[control setSelected:active forSegment:0];
}

@end

@implementation NSSegmentedCell (AlwaysTextured)

-(BOOL)_isTextured  { return YES; }

@end
