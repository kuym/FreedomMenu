#include <Cocoa/Cocoa.h>
#include <CoreGraphics/CoreGraphics.h>
#include "SSKeychain.h"

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
@class FreedomModel;

@interface FreedomMenuApp: NSObject <NSApplicationDelegate>
{
@private
	MenubarController*		_menubarController;
	UsageCheckController*	_checkController;
	
	FreedomModel*			_model;
}

@end


////////////////////////////////////////////////////////////////


@interface FreedomModel: NSObject
{
	float				_usedQuotient;
	NSString*			_password;
}

- (NSString*)username;
- (void)setUsername:(NSString*)username;

- (NSString*)password;
- (void)setPassword:(NSString*)password;

- (BOOL)autoStart;
- (void)setAutostart:(BOOL)autostart;

- (NSTimeInterval)updatePeriod;
- (void)setUpdatePeriod:(NSTimeInterval)interval;

- (float)usedQuotient;
- (void)setUsedQuotient:(float)usedQuotient;

@end


////////////////////////////////////////////////////////////////


@class MenubarView;
@class SettingsWindowController;

@interface MenubarController: NSObject
{
@private
	MenubarView*				_menubarView;
	NSMenuItem*					_detailItem;
	
	SettingsWindowController*	_settingsWindow;
	
	FreedomModel*				_model;
}

- (id)initWithModel:(FreedomModel*)model;

@property (nonatomic, strong, readonly) MenubarView* statusItemView;



@end


////////////////////////////////////////////////////////////////


@interface SettingsWindowController: NSWindowController
{
	FreedomModel* _model;
}

@property IBOutlet NSTextField*			usernameField;
@property IBOutlet NSTextField*			passwordField;
@property IBOutlet NSButton*			autoStartButton;
@property IBOutlet NSLevelIndicator*	dataLevel;
@property IBOutlet NSProgressIndicator*	indeterminateLevel;

- (id)initWithModel:(FreedomModel*)model;

- (void)showWindow:(id)sender;

@end

////////////////////////////////////////////////////////////////


@interface UsageCheckController: NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
@private
	NSTimer*			_timer;
	BOOL				_updateImminent;
	
	NSURLConnection*	_connection;
	
	NSMutableData*		_response;
	
	FreedomModel*		_model;
}

- (id)initWithModel:(FreedomModel*)model;

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
	_model = [[FreedomModel alloc] init];
	
	_menubarController = [[MenubarController alloc] initWithModel:_model];
	
	_checkController = [[UsageCheckController alloc] initWithModel:_model];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUpdateAutoStart:) name:@"changed_autostart" object:_model];
}

- (void)onUpdateAutoStart:(NSNotification*)notification
{
	LSSharedFileListRef loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil);
	
	// take a snapshot of the existing login items
	unsigned int ignore;
	NSArray* loginItemsArray = (__bridge NSArray*)LSSharedFileListCopySnapshot(loginItems, &ignore);

	// this is our path - we need to see if it exists in the login items
	NSString* applicationPath = [[NSBundle mainBundle] bundlePath];
	LSSharedFileListItemRef foundItem = nil;
	
	// try to find a login item for us
	for(id item in loginItemsArray)
	{
		LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
		CFURLRef itemPath;
		if(LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*)&itemPath, nil) == noErr)
		{
			NSString* itemPathStr = [(__bridge NSURL*)itemPath path];
			if([itemPathStr hasPrefix:applicationPath])
			{
				foundItem = itemRef;
				break;
			}
		}
	}
	
	if([_model autoStart])
	{
		if(foundItem == nil)
		{
			// add only if there's not already an item for us
			CFURLRef launchPath = CFBundleCopyBundleURL(CFBundleGetMainBundle());
			foundItem = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, nil, nil, launchPath, nil, nil);
			CFRelease(launchPath);
		}
	}
	else if(foundItem != nil)
	{
		//remove only if we're in the list
		LSSharedFileListItemRemove(loginItems, foundItem);
	}

	if(foundItem != nil)
		CFRelease(foundItem);
}

@end


////////////////////////////////////////////////////////////////


@implementation FreedomModel

- (id)init
{
	_usedQuotient = -1.f;
	
	return(self);
}

- (NSString*)username
{
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
	
	return(username);
}

- (void)setUsername:(NSString*)username
{
	if([username isEqualToString:[self username]])
		return;
	
	[[NSUserDefaults standardUserDefaults] setObject:username forKey:@"username"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_username" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_account" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed" object:self];
}

- (NSString*)password
{
	NSString* u = [self username];
	
	if(u == nil)
		return(nil);	//@@raise exception
	
	return((_password == nil)? (_password = [SSKeychain passwordForService:@"www.freedompop.com" account:u]) : _password);
	
	/*
	NSString* p = nil;
	if(_passwordSecurityItem == 0)
	{
		unsigned int passwordLength = 0;
		void* password = 0;
		SecKeychainFindInternetPassword(	NULL,
											18, "www.freedompop.com",
											0, NULL,
											(unsigned int)[u length], [u cStringUsingEncoding:NSUTF8StringEncoding],
											0, "",
											0,
											kSecProtocolTypeHTTPS, kSecAuthenticationTypeDefault,
											&passwordLength, &password,
											0
										);
		
		if((passwordLength > 0) && (password != 0))
			p = [[NSString alloc] initWithBytes:password length:passwordLength encoding:NSUTF8StringEncoding];
	}
	
	return(p);
	*/
}

- (void)setPassword:(NSString*)password
{
	if([password isEqualToString:[self password]])
		return;
	
	NSString* u = [self username];
	
	if((u == nil) || ([u length] == 0) || (password == nil) || ([password length] == 0))
		return;	//@@raise exception
	
	_password = password;
	[SSKeychain setPassword:password forService:@"www.freedompop.com" account:u];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_password" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_account" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed" object:self];
}

- (BOOL)autoStart
{
	return([[NSUserDefaults standardUserDefaults] boolForKey:@"autostart"]);
}

- (void)setAutostart:(BOOL)autostart
{
	[[NSUserDefaults standardUserDefaults] setBool:autostart forKey:@"autostart"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_autostart" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed" object:self];
}

- (NSTimeInterval)updatePeriod
{
	float period = [[NSUserDefaults standardUserDefaults] floatForKey:@"updatePeriod"];
	
	return((period == 0.f)? 3600.f : period);
}

- (void)setUpdatePeriod:(NSTimeInterval)period
{
	if(period == 0.f)
		period = 3600.f;
	
	[[NSUserDefaults standardUserDefaults] setFloat:period forKey:@"updatePeriod"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_updatePeriod" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed" object:self];
}

- (float)usedQuotient
{
	return(_usedQuotient);
}

- (void)setUsedQuotient:(float)usedQuotient
{
	_usedQuotient = usedQuotient;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed_usedQuotient" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"changed" object:self];
}


@end


////////////////////////////////////////////////////////////////


@implementation MenubarController

- (id)initWithModel:(FreedomModel*)model
{
	_model = model;
	
	NSStatusItem* statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	
	[statusItem setHighlightMode:YES];
	
	_menubarView = [[MenubarView alloc] initWithStatusItem:statusItem];
	
	[_menubarView setImage:[NSImage imageNamed:@"Status"] forSlot:MenubarViewImageSlot_normal];
	[_menubarView setImage:[NSImage imageNamed:@"StatusHighlighted"] forSlot:MenubarViewImageSlot_highlight];
	[_menubarView setImage:[NSImage imageNamed:@"StatusInd"] forSlot:MenubarViewImageSlot_indeterminate_normal];
	[_menubarView setImage:[NSImage imageNamed:@"StatusIndHighlighted"] forSlot:MenubarViewImageSlot_indeterminate_highlight];
	
	//build a menu
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"FreedomMenu"];
	int index = 0;
	_detailItem = [menu insertItemWithTitle:@"Used: Currently unknown." action:nil keyEquivalent:@"" atIndex:index++];
	[[menu insertItemWithTitle:@"Check now" action:@selector(checkNow:) keyEquivalent:@"" atIndex:index++] setTarget:self];
	[[menu insertItemWithTitle:@"FreedomPop Account..." action:@selector(goToAccount:) keyEquivalent:@"" atIndex:index++] setTarget:self];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:index++];
	[[menu insertItemWithTitle:@"Settings..." action:@selector(showSettings:) keyEquivalent:@"" atIndex:index++] setTarget:self];
	[[menu insertItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"" atIndex:index++] setTarget:self];
	
	[_menubarView setMenu:menu];
	
	_settingsWindow = [[SettingsWindowController alloc] initWithModel:_model];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUsedQuotientChanged:) name:@"changed_usedQuotient" object:_model];
	
	return(self);
}


- (void)onUsedQuotientChanged:(NSNotification*)notification
{
	float quotient = [_model usedQuotient];
	
	[_menubarView setDisplayedQuotient:quotient];
	
	if(quotient >= 0.f)
		[_detailItem setTitle:[NSString stringWithFormat:@"Used: %3.1f%%", quotient * 100.f]];
	else
		[_detailItem setTitle:@"Used: Currently unknown."];
}

- (IBAction)checkNow:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"checkNow" object:_model];
}

- (IBAction)goToAccount:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.freedompop.com/acct_usage.htm"]];
}

- (IBAction)showSettings:(id)sender
{
	//printf("Showing settings...\n");
	
	[_settingsWindow showWindow:self];
}

- (IBAction)quit:(id)sender
{
	[NSApp terminate:self];
}

- (void)dealloc
{
	[[NSStatusBar systemStatusBar] removeStatusItem:[_menubarView statusItem]];
}

@end


////////////////////////////////////////////////////////////////


@implementation SettingsWindowController


- (id)initWithModel:(FreedomModel*)model
{
	self = [super initWithWindowNibName:@"SettingsWindow"];
	
	_model = model;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUsedQuotientChanged:) name:@"changed_usedQuotient" object:_model];

	return(self);
}

- (void)onUsedQuotientChanged:(NSNotification*)notification
{
	float quotient = [_model usedQuotient];
	
	if(quotient >= 0.f)
	{
		[[self dataLevel] setIntegerValue:(int)(10.f * (1.f - quotient))];
		[[self dataLevel] setHidden:NO];
		[[self indeterminateLevel] setHidden:YES];
	}
	else
	{
		[[self indeterminateLevel] setHidden:NO];
		[[self dataLevel] setHidden:YES];
	}
}

- (void)showWindow:(id)sender
{
	[super showWindow:sender];
}

- (void)awakeFromNib
{
	[self onUsedQuotientChanged:nil];
	
	NSString* username = [_model username];
	[[self usernameField] setStringValue:(username != nil)? username : @""];
	
	NSString* password = (username != nil)? [_model password] : @"";
	[[self passwordField] setStringValue:(password != nil)? password : @""];
	
	[[self autoStartButton] setIntValue:[_model autoStart]];
	
	[[super window] setLevel:NSFloatingWindowLevel];
	[NSApp activateIgnoringOtherApps:YES];
	[[super window] makeKeyAndOrderFront:self];
}

- (IBAction)onUsernameChanged:(id)sender
{
	[_model setUsername:[[self usernameField] stringValue]];
}

- (IBAction)onPasswordChanged:(id)sender
{
	[_model setPassword:[[self passwordField] stringValue]];
}

- (IBAction)onAutoStartChanged:(id)sender
{
	[_model setAutostart:[[self autoStartButton] intValue]];
}

@end


////////////////////////////////////////////////////////////////


@implementation UsageCheckController

- (id)initWithModel:(FreedomModel*)model
{
	_model = model;
	_response = nil;
	_updateImminent = NO;
	
	[self onCheckRequested:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onModelChanged:) name:@"changed_account" object:_model];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCheckRequested:) name:@"checkNow" object:_model];
	
	// preemptively request the user's password - this will cause the Keychain UI to pop up if not authorized.
	//   this UX is much better than having it pop up a few seconds after the app starts because the user won't
	//   associate it with the action of launching the app.
	NSString* password = [_model password];
	(void)password;
	
	return(self);
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onModelChanged:(NSNotification*)notification
{
	[self onCheckRequested:notification];
}

- (void)onCheckRequested:(NSNotification*)notification
{
	_updateImminent = YES;
	_timer = [NSTimer scheduledTimerWithTimeInterval:10.f target:self selector:@selector(performCheck:) userInfo:self repeats:NO];
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
	
	[self scheduleCheckIn:[_model updatePeriod]];
	
	//printf("checking now...\n");
	
	NSString* username = [_model username];
	NSString* password = [_model password];
	
	if((username == nil) || (password == nil))
	{
		NSLog(@"FreedomMenu error: Unable to check due to there being no username or password set.\n");
		return;
	}
	
	NSMutableURLRequest* request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:@"https://www.freedompop.com/login.htm"]];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	
	NSString* post = [		NSString stringWithFormat: @"signin-username-full=%@&signin-password-full=%@&destinationURL=http://www.freedompop.com/acct_usage.htm&requestOrigin=",
							[username urlencode],
							[password urlencode]
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
	[_model setUsedQuotient:-1.f];
	
	NSLog(@"FreedomMenu error: Unable to check account status.\n");
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
			NSData* subData = [_response subdataWithRange:NSMakeRange(objectivePosition, (foundEnd.location - objectivePosition))];
			
			int usedPercentage = [[[NSString alloc] initWithData:subData encoding:NSUTF8StringEncoding] intValue];
			
			if((usedPercentage >= 0) && (usedPercentage <= 100))
			{
				[_model setUsedQuotient:(((float)usedPercentage) / 100.f)];
				valid = YES;
			}
		}
	}
	_response = nil;
	
	if(!valid)
		[_model setUsedQuotient: -1.f];
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
