#include <Cocoa/Cocoa.h>
#include <CoreGraphics/CoreGraphics.h>

@class MenubarController;

@interface FreedomMenuApp: NSObject <NSApplicationDelegate>
{
@private
	MenubarController*	_menubarController;
}

@end


////////////////////////////////////////////////////////////////


@class MenubarView;

@interface MenubarController: NSObject
{
@private
	MenubarView*	_menubarView;
}

//@property (nonatomic) BOOL hasActiveIcon;
@property (nonatomic, strong, readonly) MenubarView* statusItemView;



@end


////////////////////////////////////////////////////////////////


@interface MenubarView: NSView <NSMenuDelegate>
{
@private
	NSImage*		_image;
	NSImage*		_highlightImage;
	NSStatusItem*	_statusItem;
	BOOL			_isHighlighted;
	SEL				_action;
	id				_target;		//__unsafe_unretained
}

- (id)initWithStatusItem:(NSStatusItem *)statusItem;

- (void)setImage:(NSImage*)newImage;
- (void)setHighlightImage:(NSImage*)newImage;
- (void)setMenu:(NSMenu*)menu;
- (void)setHighlighted:(BOOL)newFlag;
- (void)setAction:(SEL)action onTarget:(id)target;

@property (nonatomic, strong, readonly) NSStatusItem* statusItem;
@property (nonatomic, setter = setHighlighted:) BOOL isHighlighted;

@end


////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////


@implementation FreedomMenuApp

- (void)applicationDidFinishLaunching:(NSNotification* )aNotification
{
	_menubarController = [[MenubarController alloc] init];
}

@end


////////////////////////////////////////////////////////////////


@implementation MenubarController

- (id)init
{
	NSStatusItem* statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	
	[statusItem setHighlightMode:YES];
	
	_menubarView = [[MenubarView alloc] initWithStatusItem:statusItem];
	
	[_menubarView setImage:[NSImage imageNamed:@"Status"]];
	[_menubarView setHighlightImage:[NSImage imageNamed:@"StatusHighlighted"]];
	//[_menubarView setAction:@selector(doStuff:) onTarget:self];
	
	//build a menu
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"FreedomMenu"];
	[menu insertItemWithTitle:@"Used: 1% (35MB of 500MB)" action:nil keyEquivalent:@"" atIndex:0];
	[[menu insertItemWithTitle:@"FreedomPop Account..." action:@selector(goToAccount:) keyEquivalent:@"" atIndex:1] setTarget:self];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:2];
	[[menu insertItemWithTitle:@"Settings..." action:@selector(showSettings:) keyEquivalent:@"" atIndex:3] setTarget:self];
	
	[_menubarView setMenu:menu];
	
	return(self);
}

/*- (IBAction)doStuff:(id)sender
{
	printf("Clicked!\n");
	
	//[_menubarView.statusItem popUpStatusItemMenu:[_menubarView.statusItem menu]];
}*/

- (IBAction)goToAccount:(id)sender
{
	printf("Going to account...\n");
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.freedompop.com/acct_usage.htm"]];
}

- (IBAction)showSettings:(id)sender
{
	printf("Showing settings...\n");
}

- (void)dealloc
{
	[[NSStatusBar systemStatusBar] removeStatusItem:[_menubarView statusItem]];
}

@end






@implementation MenubarView

@synthesize statusItem = _statusItem;

- (id)initWithStatusItem:(NSStatusItem*)statusItem
{
	CGFloat itemWidth = [statusItem length];
	CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
	NSRect itemRect = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
	self = [super initWithFrame:itemRect];

	if(self != nil)
	{
		_statusItem = statusItem;
		_statusItem.view = self;
	}
	return(self);
}

- (void)drawRect:(NSRect)dirtyRect
{
	[self.statusItem drawStatusBarBackgroundInRect:dirtyRect withHighlight:_isHighlighted];
	
	
	/*
	CGAffineTransform mtx = CGAffineTransformMake(24.f, 0.f, 0.f, 24.f, 0.f, 0.f);
	CGContextConcatCTM(context, mtx);
	
	CGContextSetLineWidth(context, 0.04166f);
	CGColorRef color = CGColorGetConstantColor(kCGColorBlack);
	CGContextSetStrokeColorWithColor(context, color);
	
	CGContextMoveToPoint(context, 0.f, 0.618f);
	CGContextAddLineToPoint(context, 1.f, 1.f);
	CGContextStrokePath(context);
	*/

	NSImage* icon = _isHighlighted ? _highlightImage : _image;
	
	if(icon)
	{
		NSSize iconSize = [icon size];
		NSRect bounds = self.bounds;
		CGFloat iconX = roundf((NSWidth(bounds) - iconSize.width) / 2);
		CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
		NSPoint iconPoint = NSMakePoint(iconX, iconY);

		CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];

		[icon drawAtPoint:iconPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		
		if(_isHighlighted)	CGContextSetRGBFillColor(context, 0.99f, 0.99f, 0.99f, 1.f);
		else				CGContextSetRGBFillColor(context, 0.08f, 0.08f, 0.08f, 1.f);
		CGContextFillRect(context, CGRectMake(iconX + 3.f, iconY + 3.f, 13.f, 5.f));
	}
}

- (void)setAction:(SEL)action onTarget:(id)target
{
}

- (void)mouseDown:(NSEvent*)theEvent
{
	NSMenu* menu = [_statusItem menu];
	[_statusItem popUpStatusItemMenu:menu];
	[self setHighlighted:NO];
	[self setNeedsDisplay:YES];
	//[NSApp sendAction:_action to:_target from:self];
}

- (void)menuWillOpen:(NSMenu*)menu
{
	[self setHighlighted:YES];
	[self setNeedsDisplay:YES];
}

- (void)menuDidClose:(NSMenu*)menu
{
	[self setHighlighted:NO];
	[self setNeedsDisplay:YES];
}



- (void)setMenu:(NSMenu*)menu
{
	[menu setDelegate:self];
	[_statusItem setMenu:menu];
}

- (void)setHighlighted:(BOOL)newFlag
{
	if(_isHighlighted != newFlag)
	{
		_isHighlighted = newFlag;
		[self setNeedsDisplay:YES];
	}
}

/*- (void)setAction:(SEL)action onTarget:(id)target
{
	_action = action;
	_target = target;
}*/

- (void)setImage:(NSImage*)newImage
{
	if(_image != newImage)
	{
		_image = newImage;
		[self setNeedsDisplay:YES];
	}
}

- (void)setHighlightImage:(NSImage*)newImage
{
	if(_highlightImage != newImage)
	{
		_highlightImage = newImage;
		if(_isHighlighted)
			[self setNeedsDisplay:YES];
	}
}

- (NSRect)globalRect
{
	NSRect frame = [self frame];
	frame.origin = [self.window convertBaseToScreen:frame.origin];
	return frame;
}

@end


////////////////////////////////////////////////////////////////


int main(int argc, const char * argv[])
{
	FreedomMenuApp* application = [[FreedomMenuApp alloc] init];

	// carbon voodoo to get icon and menu without bundle
	//ProcessSerialNumber psn = { 0, kCurrentProcess };
	//TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	//SetFrontProcess(&psn);
	
	[[NSApplication sharedApplication] setDelegate:application];
	[[NSApplication sharedApplication] run];

	return(0);
}
