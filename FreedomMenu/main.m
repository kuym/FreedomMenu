//#import "AppDelegate.h"
#include <Cocoa/Cocoa.h>

@class MenubarView;

@interface FreedomMenu : NSObject <NSApplicationDelegate>
{
@private
	MenubarView*	_menubarView;
}
//@property (assign) IBOutlet NSWindow *window;

@end


@interface MenubarView : NSView
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

@property (nonatomic, strong, readonly) NSStatusItem* statusItem;

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
	
	NSImage* icon = _isHighlighted ? _highlightImage : _image;
	NSSize iconSize = [icon size];
	NSRect bounds = self.bounds;
	CGFloat iconX = roundf((NSWidth(bounds) - iconSize.width) / 2);
	CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
	NSPoint iconPoint = NSMakePoint(iconX, iconY);

	[icon drawAtPoint:iconPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

- (void)mouseDown:(NSEvent*)theEvent
{
	[NSApp sendAction:_action to:_target from:self];
}

- (void)setHighlighted:(BOOL)newFlag
{
	if(_isHighlighted != newFlag)
	{
		_isHighlighted = newFlag;
		[self setNeedsDisplay:YES];
	}
}

- (void)setImage:(NSImage*)newImage
{
	if(_image != newImage)
	{
		_image = newImage;
		[self setNeedsDisplay:YES];
	}
}

- (void)setAlternateImage:(NSImage*)newImage
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




@implementation FreedomMenu

- (void)applicationDidFinishLaunching:(NSNotification* )aNotification
{
	NSStatusItem* statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:24.0];
	
	_menubarView = [[MenubarView alloc] initWithStatusItem:statusItem];
}

- (void)dealloc
{
	[[NSStatusBar systemStatusBar] removeStatusItem:[_menubarView statusItem]];
}

@end



int main(int argc, const char * argv[])
{
	FreedomMenu* application = [[FreedomMenu alloc] init];

	// carbon voodoo to get icon and menu without bundle
	//ProcessSerialNumber psn = { 0, kCurrentProcess };
	//TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	//SetFrontProcess(&psn);
	
	[[NSApplication sharedApplication] setDelegate:application];
	[[NSApplication sharedApplication] run];

	return(0);
}
