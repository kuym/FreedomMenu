#include <Cocoa/Cocoa.h>
#include <CoreGraphics/CoreGraphics.h>


@implementation NSString (NSString_Extended)

- (NSString*)urlencode
{
	NSMutableString* output = [NSMutableString string];
	const unsigned char* source = (const unsigned char*)[self UTF8String];
	size_t sourceLen = strlen((const char*)source);
	for(int i = 0; i < sourceLen; ++i)
	{
		const unsigned char thisChar = source[i];
		if (thisChar == ' ')
		{
			[output appendString:@"+"];
		}
		else if(	thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
					(thisChar >= 'a' && thisChar <= 'z') ||
					(thisChar >= 'A' && thisChar <= 'Z') ||
					(thisChar >= '0' && thisChar <= '9'))
		{
			[output appendFormat:@"%c", thisChar];
		}
		else
			[output appendFormat:@"%%%02X", thisChar];
	}
	return(output);
}
@end

////////////////////////////////////////////////////////////////


@class MenubarController;
@class UsageCheckController;

@interface FreedomMenuApp: NSObject <NSApplicationDelegate>
{
@private
	MenubarController*		_menubarController;
	UsageCheckController*	_checkController;
}

@end


////////////////////////////////////////////////////////////////


@class MenubarView;

@interface MenubarController: NSObject
{
@private
	MenubarView*	_menubarView;
	NSMenuItem*		_detailItem;
}

- (void)updateUsedQuotient:(float)quotient;

//@property (nonatomic) BOOL hasActiveIcon;
@property (nonatomic, strong, readonly) MenubarView* statusItemView;



@end


////////////////////////////////////////////////////////////////


@interface UsageCheckController: NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
@private
	NSString*			_username;
	NSString*			_password;
	
	NSTimer*			_timer;
	NSTimeInterval		_timerPeriod;
	BOOL				_updateImminent;
	
	NSURLConnection*	_connection;
	
	NSMutableData*		_response;
	
	float				_usedQuotient;
	SEL					_usedQuotientOnChange;
	id					_usedQuotientOnChangeTarget;
}

- (id)initWithUsername:(NSString*)username password:(NSString*)password;

- (void)setUsername:(NSString*)username;
- (void)setPassword:(NSString*)password;

- (void)onUsedQuotientChanged:(SEL)handler target:(id)target;

- (void)setUpdatePeriod:(NSTimeInterval)interval;

@property (nonatomic, setter = setUsername:) NSString* username;
@property (nonatomic, setter = setPassword:) NSString* password;
@property (nonatomic, readonly) float usedQuotient;
@property (nonatomic, readonly) NSTimeInterval updatePeriod;


@end


////////////////////////////////////////////////////////////////

typedef enum
{
	MenubarViewImageSlot_normal = 0,
	MenubarViewImageSlot_highlight = 1,
	MenubarViewImageSlot_indeterminate_normal = 2,
	MenubarViewImageSlot_indeterminate_highlight = 3,
	
	MenubarViewImageSlot__pastEnd
} MenubarViewImageSlot;

@interface MenubarView: NSView <NSMenuDelegate>
{
@private
	NSImage*		_image[4];
	NSStatusItem*	_statusItem;
	BOOL			_isHighlighted;
	SEL				_action;
	id				_target;		//__unsafe_unretained
	
	float			_displayedQuotient;
}

- (id)initWithStatusItem:(NSStatusItem*)statusItem;

- (void)setImage:(NSImage*)newImage forSlot:(MenubarViewImageSlot)slot;
//- (void)setHighlightImage:(NSImage*)newImage;
- (void)setMenu:(NSMenu*)menu;
- (void)setHighlighted:(BOOL)newFlag;
- (void)setAction:(SEL)action onTarget:(id)target;

- (void)setDisplayedQuotient:(float)quotient;

@property (nonatomic, strong, readonly) NSStatusItem* statusItem;
@property (nonatomic, setter = setHighlighted:) BOOL isHighlighted;
@property (nonatomic, setter = setDisplayedQuotient:) float displayedQuotient;

@end


////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////


@implementation FreedomMenuApp

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
	_menubarController = [[MenubarController alloc] init];
	
	_checkController = [[UsageCheckController alloc] initWithUsername:@"YOURUSERNAME" password:@"YOURPASSWORD"];
	
	[_checkController onUsedQuotientChanged:@selector(onQuotientUpdate) target:self];
}

- (void)onQuotientUpdate
{
	[_menubarController updateUsedQuotient:[_checkController usedQuotient]];
}

@end


////////////////////////////////////////////////////////////////


@implementation MenubarController

- (id)init
{
	NSStatusItem* statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	
	[statusItem setHighlightMode:YES];
	
	_menubarView = [[MenubarView alloc] initWithStatusItem:statusItem];
	
	[_menubarView setImage:[NSImage imageNamed:@"Status"] forSlot:MenubarViewImageSlot_normal];
	[_menubarView setImage:[NSImage imageNamed:@"StatusHighlighted"] forSlot:MenubarViewImageSlot_highlight];
	[_menubarView setImage:[NSImage imageNamed:@"StatusInd"] forSlot:MenubarViewImageSlot_indeterminate_normal];
	[_menubarView setImage:[NSImage imageNamed:@"StatusIndHighlighted"] forSlot:MenubarViewImageSlot_indeterminate_highlight];
	
	//[_menubarView setAction:@selector(doStuff:) onTarget:self];
	
	//build a menu
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"FreedomMenu"];
	_detailItem = [menu insertItemWithTitle:@"Used: Currently unknown." action:nil keyEquivalent:@"" atIndex:0];
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

- (void)updateUsedQuotient:(float)quotient
{
	[_menubarView setDisplayedQuotient:quotient];
	
	if(quotient >= 0.f)
		[_detailItem setTitle:[NSString stringWithFormat:@"Used: %3.1f%%", quotient * 100.f]];
	else
		[_detailItem setTitle:@"Used: Currently unknown."];
}

- (IBAction)goToAccount:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.freedompop.com/acct_usage.htm"]];
}

- (IBAction)showSettings:(id)sender
{
	printf("Would show settings...\n");
}

- (void)dealloc
{
	[[NSStatusBar systemStatusBar] removeStatusItem:[_menubarView statusItem]];
}

@end


////////////////////////////////////////////////////////////////


@implementation UsageCheckController

@synthesize username = _username;
@synthesize password = _password;
@synthesize usedQuotient = _usedQuotient;
@synthesize updatePeriod = _timerPeriod;

- (id)init
{
	_username = nil;
	_password = nil;
	_response = nil;
	_usedQuotient = -1.f;
	_updateImminent = NO;
	
	_timerPeriod = 3600.f;	// update by default each hour
	
	return(self);
}

- (id)initWithUsername:(NSString *)username password:(NSString *)password
{
	self = [self init];
	
	_username = username;
	_password = password;
	
	[self checkNow];
	
	return(self);
}

- (void)setUsername:(NSString*)username
{
	_username = username;
	[self checkNow];
}
- (void)setPassword:(NSString*)password
{
	_password = password;
	[self checkNow];
}

- (void)onUsedQuotientChanged:(SEL)handler target:(id)target
{
	_usedQuotientOnChange = handler;
	_usedQuotientOnChangeTarget = target;
}

- (void)setUpdatePeriod:(NSTimeInterval)interval
{
	_timerPeriod = interval;
	if(!_updateImminent)
		[self scheduleCheckIn:_timerPeriod];
}

- (void)checkNow
{
	_updateImminent = YES;
	_timer = [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(performCheck:) userInfo:self repeats:NO];
}

- (void)scheduleCheckIn:(NSTimeInterval)seconds
{
	if(!_updateImminent)
	{
		if((_timer != nil) && [_timer isValid])
			[_timer invalidate];
		_timer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(performCheck:) userInfo:self repeats:NO];
	}
}

- (void)performCheck:(NSTimer*)timer
{
	_updateImminent = NO;
	
	[self scheduleCheckIn:_timerPeriod];
	
	//printf("checking now...\n");
	
	if((_username == nil) || (_password == nil))
	{
		//printf("unable to check, no username or password.\n");
		return;
	}
		
	NSMutableURLRequest* request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:@"https://www.freedompop.com/login.htm"]];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	
	NSString* post = [NSString stringWithFormat: @"signin-username-full=%@&signin-password-full=%@&destinationURL=http://www.freedompop.com/acct_usage.htm&requestOrigin=",
							[_username urlencode],
							[_password urlencode]
						];
	
	NSData* postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	
	NSString* postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setHTTPBody:postData];
	
	_response = nil;
	_connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
	[self setUsedQuotient:-1.f];
	
	printf("error.\n");
}

- (NSURLRequest*)connection:(NSURLConnection*)connection willSendRequest:(NSURLRequest*)request redirectResponse:(NSURLResponse*)response
{
	//printf("will redirect.\n");
	
	return(request);
}
- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSHTTPURLResponse*)response
{
	//printf("got response.\n");
	
	NSNumber* length = (NSNumber*)[[response allHeaderFields] objectForKey:@"Content-Length"];
	size_t responseLength = (length != nil)? [length intValue] : 0;
	
	if((_response == nil) && (responseLength > 0))
		_response = [[NSMutableData alloc] initWithCapacity:responseLength];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
	//printf("rxd data, %lu bytes.\n", (unsigned long)[data length]);
	
	if(_response == nil)
		_response = [[NSMutableData alloc] initWithCapacity:[data length]];
	
	[_response appendData:data];
}

- (void)connection:(NSURLConnection*)connection	didSendBodyData:(NSInteger)bytesWritten
												totalBytesWritten:(NSInteger)totalBytesWritten
												totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	//printf("progress %li %li %li.\n", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
	//printf("finished.\n");
	
	_connection = nil;
	
	char const* searchString = "<div class=\"colorBar\" style=\"width:";
	size_t searchStringLen = strlen(searchString);
	NSData* htmlNodeOfInterest = [NSData dataWithBytes:searchString length:searchStringLen];
	NSRange found = [_response rangeOfData:htmlNodeOfInterest options:0 range:NSMakeRange(0, [_response length])];
	
	BOOL valid = NO;
	if(found.location != NSNotFound)
	{
		//printf("found at %lu, %lu\n", (unsigned long)found.location, (unsigned long)found.length);
		
		NSData* endMarker = [NSData dataWithBytes:"%" length:1];
		size_t objectivePosition = found.location + searchStringLen;
		NSRange foundEnd = [_response rangeOfData:endMarker options:0 range:NSMakeRange(objectivePosition, [_response length] - objectivePosition)];
		
		// accept up to 10 decimal digits
		if((foundEnd.location != NSNotFound) && ((foundEnd.location - objectivePosition) < 10))
		{
			NSData* subData = [_response subdataWithRange:NSMakeRange(found.location, (foundEnd.location - found.location))];
			
			int usedPercentage = [[[NSString alloc] initWithData:subData encoding:NSUTF8StringEncoding] intValue];
			
			if((usedPercentage >= 0) && (usedPercentage <= 100))
			{
				[self setUsedQuotient:(((float)usedPercentage) / 100.f)];
				valid = YES;
				
				//printf("Used quotient is %f\n", _usedQuotient);
			}
		}
	}
	_response = nil;
	
	if(!valid)
		[self setUsedQuotient: -1.f];
}

- (void) setUsedQuotient:(float)quotient
{
	_usedQuotient = quotient;
	if(_usedQuotientOnChange != nil)
		[NSApp sendAction:_usedQuotientOnChange to:_usedQuotientOnChangeTarget from:self];
}


@end

////////////////////////////////////////////////////////////////


@implementation MenubarView

@synthesize statusItem = _statusItem;
@synthesize displayedQuotient = _displayedQuotient;

- (id)initWithStatusItem:(NSStatusItem*)statusItem
{
	CGFloat itemWidth = [statusItem length];
	CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
	NSRect itemRect = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
	self = [super initWithFrame:itemRect];
	
	_displayedQuotient = -1.f;	// indeterminate

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

	NSImage* icon = (_displayedQuotient >= 0.f)? (_isHighlighted ? _image[MenubarViewImageSlot_highlight] : _image[MenubarViewImageSlot_normal])
				: (_isHighlighted ? _image[MenubarViewImageSlot_indeterminate_highlight] : _image[MenubarViewImageSlot_indeterminate_normal]);
	
	if(icon)
	{
		NSSize iconSize = [icon size];
		NSRect bounds = self.bounds;
		CGFloat iconX = roundf((NSWidth(bounds) - iconSize.width) / 2);
		CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
		NSPoint iconPoint = NSMakePoint(iconX, iconY);

		CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
		[icon drawAtPoint:iconPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		
		if(_displayedQuotient >= 0.f)
		{
			if(_isHighlighted)	CGContextSetRGBFillColor(context, 0.99f, 0.99f, 0.99f, 1.f);
			else				CGContextSetRGBFillColor(context, 0.08f, 0.08f, 0.08f, 1.f);
			
			// display used quotient of 0.0 as full and 1.0 as empty, like a battery charge meter
			CGContextFillRect(context, CGRectMake(iconX + 3.f, iconY + 3.f, 19.f * (1.f - _displayedQuotient), 5.f));
		}
	}
}

- (void)setAction:(SEL)action onTarget:(id)target
{
}

- (void)setDisplayedQuotient:(float)quotient
{
	_displayedQuotient = quotient;
	[self setNeedsDisplay:YES];
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

- (void)setImage:(NSImage*)newImage forSlot:(MenubarViewImageSlot)slot
{
	if(slot >= MenubarViewImageSlot__pastEnd)
		return;
	if(_image[slot] != newImage)
	{
		_image[slot] = newImage;
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


int main(int argc, const char*  argv[])
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
