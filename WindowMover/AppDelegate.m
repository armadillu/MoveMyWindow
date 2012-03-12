//
//  AppDelegate.m
//  WindowMover
//
//  Created by Oriol Ferrer Mesià on 12/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#include <Carbon/Carbon.h>

float flip(float val) ;

static AXUIElementRef getFrontMostApp (){
    pid_t pid;
    ProcessSerialNumber psn;
	
    GetFrontProcess(&psn);
    GetProcessPID(&psn, &pid);
    return AXUIElementCreateApplication(pid);
}


static bool amIAuthorized (){
    if (AXAPIEnabled() != 0) {
        /* Yehaa, all apps are authorized */
        return true;
    }
    /* Bummer, it's not activated, maybe we are trusted */
    if (AXIsProcessTrusted() != 0) {
        /* Good news, we are already trusted */
        return true;
    }
    /* Crap, we are not trusted...
     * correct behavior would now be to become a root process using
     * authorization services and then call AXMakeProcessTrusted() to make
     * ourselves trusted, then restart... I'll skip this here for
     * simplicity.
     */
    return false;
}


@implementation AppDelegate



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
	_statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [_statusItem setHighlightMode:YES];
    [_statusItem setEnabled:YES];
    [_statusItem setMenu:menu];
	[_statusItem setTarget:self];	
	[_statusItem setImage:[NSImage imageNamed:@"menu.png"]];
	[self registerKeys];
	lastAbsoluteMove = nil;
	timeoutTimer = nil;
}


- (void)dealloc{
	[self unregisterKeys];
    [super dealloc];
}


-(void)timeOut{
	
	NSLog(@"timeOut...");
	if (lastAbsoluteMove!= nil) [lastAbsoluteMove release];
		lastAbsoluteMove = nil;
	timeoutTimer = nil;
}

-(void)moveWindow:(NSDictionary*)offset{

	if (timeoutTimer != nil) [timeoutTimer invalidate];
	timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeOut) userInfo:nil repeats:NO];
	
    AXValueRef temp;
    CGSize windowSize;
    CGPoint windowPosition;
    CFStringRef windowTitle;
    AXUIElementRef frontMostApp;
    AXUIElementRef frontMostWindow;
	
    if (!amIAuthorized()) {
        printf("Can't use accessibility API!\n");
        return ;
    }
	
    frontMostApp = getFrontMostApp();
    AXUIElementCopyAttributeValue( frontMostApp, kAXFocusedWindowAttribute, (CFTypeRef *)&frontMostWindow );
	
	if (frontMostWindow == nil){ 
		NSLog(@"Can't get FrontMost Window!");
		return;
	}
	
    AXUIElementCopyAttributeValue( frontMostWindow, kAXTitleAttribute, (CFTypeRef *)&windowTitle );
	if (windowTitle == nil){ 
		NSLog(@"Can't get FrontMost Window windowTitle!");
		return;
	}
    AXUIElementCopyAttributeValue(frontMostWindow, kAXSizeAttribute, (CFTypeRef *)&temp);
	if (temp == nil){ 
		NSLog(@"Can't get FrontMost Window position!");
		return;
	}

    AXValueGetValue(temp, kAXValueCGSizeType, &windowSize);	
    CFRelease(temp);	
    AXUIElementCopyAttributeValue( frontMostWindow, kAXPositionAttribute, (CFTypeRef *)&temp );
    AXValueGetValue(temp, kAXValueCGPointType, &windowPosition);
    CFRelease(temp);
		 
	//NSLog(@"current window position %f %f", windowPosition.x, windowPosition.y);
	//NSLog(@"current window size %f %f", windowSize.width, windowSize.height);
	
	//NSLog(@"offset: %@",offset);
	
	if ( [[offset objectForKey:@"relative"] boolValue] == true ){	//apply offset from where we are
		
	
		windowPosition.x += [[offset objectForKey:@"x"] intValue];
		windowPosition.y += [[offset objectForKey:@"y"] intValue];		

		if (lastAbsoluteMove!= nil) [lastAbsoluteMove release];
		lastAbsoluteMove = nil;
		
	}else{	//move N, S, E, W inside that screen

		NSArray * screens = [NSScreen screens];
		int index = -1;
		int nextIndex = -1;
		for (int i = 0; i < [screens count]; i++){
			NSScreen * s = [screens objectAtIndex:i];
			NSRect f = [s frame];
			NSPoint p = NSMakePoint(windowPosition.x , flip(windowPosition.y) );
			//NSLog(@"Point %@ in Rect %@", NSStringFromPoint(p), NSStringFromRect(f));
			if (  NSPointInRect ( p , NSInsetRect(f, 0, 0 ) ) ){
				index = i;
			}
		}

		//NSLog(@"win is in screen %d", index);	

		if (index != -1){
			
			nextIndex = index + 1;
			if (nextIndex >= [screens count]) {
				nextIndex = 0;
			}
			
			NSScreen * screen = [screens objectAtIndex:index];		
			NSScreen * nextScreen = [screens objectAtIndex:nextIndex];
			
			if (lastAbsoluteMove!= nil) [lastAbsoluteMove release];

			NSPoint screenPos = [screen visibleFrame].origin; 			
			int sH = [screen visibleFrame].size.height;
			int nsH = [nextScreen visibleFrame].size.height;
			int sY= [screen visibleFrame].origin.y;
			int nsY=[nextScreen visibleFrame].origin.y;
			float ratioY = (float)nsH / sH;
			float ratioX = (float)[nextScreen visibleFrame].size.width / (float) [screen visibleFrame].size.width;
			float margin = 1;
			
			//NSLog(@"rx: %f ry: %f", ratioX, ratioY );
			
			if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString:@"N"] ){   // NORTH ////////////////////////
								
				NSLog(@"NORTH!");
				if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString: lastAbsoluteMove] ){	//move to next screen
					//windowSize.width *= ratioX;
					//windowSize.height *= ratioY;
					windowPosition.y = flip(nsY + nsH) + margin;
					windowPosition.x = ( [nextScreen visibleFrame].origin.x + ratioX * ( windowPosition.x - screenPos.x ) );
				}else{	
					windowPosition.y = flip(sY + sH) + margin ;
				}
			}

			if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString:@"S"] ){   // SOUTH ////////////////////////
				NSLog(@"SOUTH!");
				if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString: lastAbsoluteMove] ){	//move to next screen
					//windowSize.width *= ratioX;
					//windowSize.height *= ratioY;
					//NSLog(@"new window size %f %f", windowSize.width, windowSize.height);
					windowPosition.y = flip( nsY + windowSize.height ) - margin;//flip!
					windowPosition.x = [nextScreen visibleFrame].origin.x + ratioX * ( windowPosition.x - screenPos.x ) ;

				}else{	
					
					windowPosition.y = flip( sY + windowSize.height ) - margin;//flip!
				}
			}
			
			if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString:@"E"] ){   // EAST ////////////////////////
				NSLog(@"EAST!");
				if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString: lastAbsoluteMove] ){	//move to next screen
					
					//NSLog(@"percentY: %f", 0);
					//windowSize.width *= ratioX;					
					windowPosition.y = flip(  nsY ) + ratioY * ( windowPosition.y - flip( screenPos.y )) ;
					//windowSize.height *= ratioY;
					windowPosition.x = [nextScreen visibleFrame].origin.x + [nextScreen visibleFrame].size.width - windowSize.width -margin;
				}else{	
					windowPosition.x = [screen visibleFrame].origin.x +  [screen visibleFrame].size.width - windowSize.width -margin;
				}
			}

			if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString:@"W"] ){   // WEST ////////////////////////
				NSLog(@"WEST!");
				if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString: lastAbsoluteMove] ){	//move to next screen
					
					//NSLog(@"percentY: %f", 0);
					//windowSize.width *= ratioX;					
					windowPosition.y = flip(  nsY ) + ratioY * ( windowPosition.y - flip( screenPos.y )) ;
					//windowSize.height *= ratioY;
					windowPosition.x = [nextScreen visibleFrame].origin.x +margin;
				}else{	
					windowPosition.x = [screen visibleFrame].origin.x +margin;
				}
			}
		}
		lastAbsoluteMove = [[offset objectForKey:@"abosolutePosition"] retain];
	}
	
	AXError err;

	temp = AXValueCreate(kAXValueCGPointType, &windowPosition);
	err = AXUIElementSetAttributeValue(frontMostWindow, kAXPositionAttribute, temp);
	//printf("err at set position %d\n", err);
    CFRelease(temp);

	windowSize.width = (int)windowSize.width;
	windowSize.height = (int)windowSize.height;
	temp = AXValueCreate(kAXValueCGSizeType, &windowSize);
    err = AXUIElementSetAttributeValue(frontMostWindow, kAXSizeAttribute, temp);
	//printf("err at set size %d\n", err);
    CFRelease(temp);


    CFRelease(frontMostWindow);
    CFRelease(frontMostApp);
}

float flip(float val) {
	return [[NSScreen mainScreen] frame].size.height - val;
}

- (void) registerKeys{
	
	keys = [[DDHotKeyCenter alloc] init];
	[keys registerHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveUp:) object:nil];
	[keys registerHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveDown:) object:nil];
	[keys registerHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveLeft:) object:nil];
	[keys registerHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveRight:) object:nil];

	[keys registerHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushUp:) object:nil];
	[keys registerHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushDown:) object:nil];
	[keys registerHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushLeft:) object:nil];
	[keys registerHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushRight:) object:nil];
}

- (void) unregisterKeys{
	[keys unregisterHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSAlternateKeyMask];
	[keys unregisterHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSAlternateKeyMask];
	[keys unregisterHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSAlternateKeyMask];
	[keys unregisterHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSAlternateKeyMask];
	
	[keys unregisterHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask];

	[keys release];
}


-(IBAction)moveUp:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
		[NSNumber numberWithBool:true], @"relative", 
		[NSNumber numberWithInt:0], @"x", 
		[NSNumber numberWithInt:-100], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)moveDown:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:true], @"relative", 
	  [NSNumber numberWithInt:0], @"x", 
	  [NSNumber numberWithInt:100], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)moveRight:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:true], @"relative", 
	  [NSNumber numberWithInt:100], @"x", 
	  [NSNumber numberWithInt:00], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)moveLeft:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:true], @"relative", 
	  [NSNumber numberWithInt:-100], @"x", 
	  [NSNumber numberWithInt:0], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)pushUp:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:false], @"relative", 
	  @"N", @"abosolutePosition", nil]
			   afterDelay:0.00];
}

-(IBAction)pushDown:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:false], @"relative", 
	  @"S", @"abosolutePosition", nil]
			   afterDelay:0.00];
}

-(IBAction)pushRight:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:false], @"relative", 
	  @"E", @"abosolutePosition", nil]
			   afterDelay:0.00];
}

-(IBAction)pushLeft:(id)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:false], @"relative", 
	  @"W", @"abosolutePosition", nil]
			   afterDelay:0.00];
}


@end
