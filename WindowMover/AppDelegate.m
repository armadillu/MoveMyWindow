//
//  AppDelegate.m
//  WindowMover
//
//  Created by Oriol Ferrer Mesià on 12/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//
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
	[_statusItem setImage:[NSImage imageNamed:@"menuIcon"]];
	[self registerKeys];
	lastAbsoluteMove = nil;
	timeoutTimer = nil;
	offset = 25; //defaults
	[self loadPrefs];
	[offsetSlider setFloatValue:offset];
	currentAction = NOTHING;
	centeredRecently = centeredResizedRecently = fulledRecently = halfedRecently = false;
	updateTimer = nil;
	timeOutTime = 2.0;
}


-(void)update:(id)whatever{
	//NSLog(@"update");
	offsetNow += offset * 0.033f;
	if (offsetNow > offset) offsetNow = offset;

	switch (currentAction) {
		case NOTHING: break;
		case MOVE_L: [self moveLeft:nil]; break;
		case MOVE_R: [self moveRight:nil]; break;
		case MOVE_U: [self moveUp:nil]; break;
		case MOVE_D: [self moveDown:nil]; break;
		case GROW_L: [self shrinkX:nil]; break;
		case GROW_R: [self growX:nil]; break;
		case GROW_D: [self shrinkY:nil]; break;
		case GROW_U: [self growY:nil]; break;
	}
}

-(void)handleTrigger:(NSEvent*) e{
	if ([e type] == NSKeyDown){
		//NSLog(@"handleTirgegr keyDown");
		offsetNow = 0;
		if ( updateTimer == nil ){
			updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.016 target:self selector:@selector(update:) userInfo:nil repeats:YES] ;
			[updateTimer retain];
		}
	}else{
		//NSLog(@"handleTirgegr keyUp");
		if ( updateTimer != nil){
			[updateTimer invalidate];
			[updateTimer release];
			updateTimer = nil;
		}
	}
}

-(void)loadPrefs{
	NSUserDefaults * def = [NSUserDefaults standardUserDefaults];
	if ( [def stringForKey:@"offset"] ){
		offset = [def floatForKey:@"offset"] ;
		if (offset > 50) offset = 50;
		if (offset < 1) offset = 1;
	}
}


- (void)dealloc{
	[self unregisterKeys];
    [super dealloc];
}


-(IBAction)changeOffset:(id)sender{
	offset = [sender floatValue];
	NSUserDefaults * def = [NSUserDefaults standardUserDefaults];
	[def setFloat:offset forKey:@"offset"];
	[def synchronize];
}

-(void)timeOut{
	
	//NSLog(@"timeOut...");
	if (lastAbsoluteMove!= nil) [lastAbsoluteMove release];
		lastAbsoluteMove = nil;
	timeoutTimer = nil;
	centeredRecently = false;
	centeredResizedRecently = false;
	fulledRecently = false;
}

-(void)resizeWindow:(NSDictionary*)offset_{

    AXValueRef temp;
    CGSize windowSize;
    CGPoint windowPosition;
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

	windowSize.width += [[offset_ objectForKey:@"x"] intValue];
	windowSize.height += [[offset_ objectForKey:@"y"] intValue];

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

-(void)moveWindow:(NSDictionary*)offset{

	if (timeoutTimer != nil) [timeoutTimer invalidate];
	timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeOutTime target:self selector:@selector(timeOut) userInfo:nil repeats:NO];
	
    AXValueRef temp;
    CGSize windowSize;
    CGPoint windowPosition;
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
			NSPoint p = NSMakePoint(windowPosition.x + windowSize.width / 2 , flip(windowPosition.y + windowSize.height / 2) );
			//NSLog(@"Point %@ in Rect %@", NSStringFromPoint(p), NSStringFromRect(f));
			if (  NSPointInRect ( p , NSInsetRect(f, 0, 0 ) ) ){
				index = i;
			}
		}

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
			float margin = 0;
			
			//NSLog(@"rx: %f ry: %f", ratioX, ratioY );
			
			if ( [[offset objectForKey:@"abosolutePosition"] isEqualToString:@"N"] ){   // NORTH ////////////////////////
								
				//NSLog(@"NORTH!");
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
				//NSLog(@"SOUTH!");
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
				//NSLog(@"EAST!");
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
				//NSLog(@"WEST!");
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
	[keys registerHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveUpTrigger:) object:nil ];
	[keys registerHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveDownTrigger:) object:nil];
	[keys registerHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveLeftTrigger:) object:nil ];
	[keys registerHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSAlternateKeyMask target:self action:@selector(moveRightTrigger:) object:nil ];

	[keys registerHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushUp:) object:nil ];
	[keys registerHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushDown:) object:nil ];
	[keys registerHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushLeft:) object:nil ];
	[keys registerHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(pushRight:) object:nil ];

	[keys registerHotKeyWithKeyCode:126 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(shrinkYTrigger:) object:nil ];
	[keys registerHotKeyWithKeyCode:125 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(growYTrigger:) object:nil ];
	[keys registerHotKeyWithKeyCode:123 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(shrinkXTrigger:) object:nil ];
	[keys registerHotKeyWithKeyCode:124 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask target:self action:@selector(growXTrigger:) object:nil ];

	[keys registerHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSCommandKeyMask target:self action:@selector(maximize:) object:nil ];
	[keys registerHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSCommandKeyMask target:self action:@selector(center:) object:nil ]; //right
	[keys registerHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSCommandKeyMask target:self action:@selector(halfScreenSize:) object:nil ]; //left
	[keys registerHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSCommandKeyMask target:self action:@selector(centerAndResize:) object:nil ]; //down

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

	[keys unregisterHotKeyWithKeyCode:126 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:125 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:123 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:124 modifierFlags:NSAlternateKeyMask|NSCommandKeyMask];

	[keys unregisterHotKeyWithKeyCode:126 modifierFlags:NSControlKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:125 modifierFlags:NSControlKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:123 modifierFlags:NSControlKeyMask|NSCommandKeyMask];
	[keys unregisterHotKeyWithKeyCode:124 modifierFlags:NSControlKeyMask|NSCommandKeyMask];


	[keys release];
}

-(void)maximize:(NSEvent*)sender{

	if ([sender type] == NSKeyDown){

		if (timeoutTimer != nil) [timeoutTimer invalidate];
		timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeOutTime target:self selector:@selector(timeOut) userInfo:nil repeats:NO];

		AXValueRef temp;
		CGSize windowSize;
		CGPoint windowPosition;
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

		NSArray * screens = [NSScreen screens];
		int index = -1;

		for (int i = 0; i < [screens count]; i++){
			NSScreen * s = [screens objectAtIndex:i];
			NSRect f = [s frame];
			NSPoint p = NSMakePoint(windowPosition.x + windowSize.width / 2 , flip(windowPosition.y + windowSize.height / 2) );
			//NSLog(@"Point %@ in Rect %@", NSStringFromPoint(p), NSStringFromRect(f));
			if (  NSPointInRect ( p , NSInsetRect(f, 0, 0 ) ) ){
				index = i;
			}
		}

		if (index != -1){

			if (fulledRecently){ //user pressed 2 times in a row center, so jump center across screens
				index = index + 1;
				if (index >= [screens count]) {
					index = 0;
				}
			}

			//NSLog(@"maximize %d", index);

			NSScreen * screen = [screens objectAtIndex:index];
			NSPoint screenPos = [screen frame].origin;
			NSSize screenSize = [screen frame].size;

			screenPos.y = flip(screenSize.height + screenPos.y);

			AXError err;
			NSSize smallSize = NSMakeSize(800, 600);
			temp = AXValueCreate(kAXValueCGSizeType, &smallSize);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXSizeAttribute, temp);
			CFRelease(temp);

			temp = AXValueCreate(kAXValueCGPointType, &screenPos);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXPositionAttribute, temp);
			//printf("err at set position %d\n", err);
			CFRelease(temp);

			temp = AXValueCreate(kAXValueCGSizeType, &screenSize);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXSizeAttribute, temp);
			//printf("err at set size %d\n", err);
			CFRelease(temp);

			CFRelease(frontMostWindow);
			CFRelease(frontMostApp);
		}
		centeredRecently = centeredResizedRecently = fulledRecently = halfedRecently = false;
		fulledRecently = true;
	}
}

-(void)halfScreenSize:(NSEvent*)sender{

	if ([sender type] == NSKeyDown){

		if (timeoutTimer != nil) [timeoutTimer invalidate];
		timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeOutTime target:self selector:@selector(timeOut) userInfo:nil repeats:NO];

		AXValueRef temp;
		CGSize windowSize;
		CGPoint windowPosition;
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

		NSArray * screens = [NSScreen screens];
		int index = -1;

		for (int i = 0; i < [screens count]; i++){
			NSScreen * s = [screens objectAtIndex:i];
			NSRect f = [s frame];
			NSPoint p = NSMakePoint(windowPosition.x + windowSize.width / 2 , flip(windowPosition.y + windowSize.height / 2) );
			//NSLog(@"Point %@ in Rect %@", NSStringFromPoint(p), NSStringFromRect(f));
			if (  NSPointInRect ( p , NSInsetRect(f, 0, 0 ) ) ){
				index = i;
			}
		}

		if (index != -1){

			//NSLog(@"maximize %d", index);

			NSScreen * screen = [screens objectAtIndex:index];
			NSPoint screenPos = [screen frame].origin;
			NSSize screenSize = [screen frame].size;
			screenSize.width /= 2;

			if (halfedRecently){ //user pressed 2 times in a row center, so jump center across screens
				if ( windowPosition.x - screenPos.x < screenSize.width * 0.5 ){
					//NSLog(@"one!");
					screenPos.x += screenSize.width;
				}else{
					//NSLog(@"two!");
				}
			}

			screenPos.y = flip(screenSize.height + screenPos.y);

			AXError err;
			NSSize smallSize = NSMakeSize(800, 600);
			temp = AXValueCreate(kAXValueCGSizeType, &smallSize);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXSizeAttribute, temp);
			CFRelease(temp);

			temp = AXValueCreate(kAXValueCGPointType, &screenPos);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXPositionAttribute, temp);
			//printf("err at set position %d\n", err);
			CFRelease(temp);

			temp = AXValueCreate(kAXValueCGSizeType, &screenSize);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXSizeAttribute, temp);
			//printf("err at set size %d\n", err);
			CFRelease(temp);

			CFRelease(frontMostWindow);
			CFRelease(frontMostApp);
		}
		centeredRecently = centeredResizedRecently = fulledRecently = halfedRecently = false;
		halfedRecently = true;
	}
}

-(void)center:(NSEvent*)sender{

	if ([sender type] == NSKeyDown){

		//NSLog(@"center");
		if (timeoutTimer != nil) [timeoutTimer invalidate];
		timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeOutTime target:self selector:@selector(timeOut) userInfo:nil repeats:NO];		

		AXValueRef temp;
		CGSize windowSize;
		CGPoint windowPosition;
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

		NSArray * screens = [NSScreen screens];
		int index = -1;
		int nextIndex = -1;
		for (int i = 0; i < [screens count]; i++){
			NSScreen * s = [screens objectAtIndex:i];
			NSRect f = [s frame];
			NSPoint p = NSMakePoint(windowPosition.x + windowSize.width / 2 , flip(windowPosition.y + windowSize.height / 2)  );
			//NSLog(@"Point %@ in Rect %@", NSStringFromPoint(p), NSStringFromRect(f));
			if (  NSPointInRect ( p , NSInsetRect(f, 0, 0 ) ) ){
				index = i;
			}
		}

		if (index != -1){

			if (centeredRecently){ //user pressed 2 times in a row center, so jump center across screens
				index = index + 1;
				if (index >= [screens count]) {
					index = 0;
				}
			}

			NSScreen * screen = [screens objectAtIndex:index];
			NSPoint screenPos = [screen visibleFrame].origin;
			NSSize screenSize = [screen visibleFrame].size;

			screenPos.x += screenSize.width * 0.5f - windowSize.width * 0.5f ;
			screenPos.y = flip(screenSize.height + screenPos.y) + screenSize.height * 0.5 - windowSize.height * 0.5;

			AXError err;
			temp = AXValueCreate(kAXValueCGPointType, &screenPos);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXPositionAttribute, temp);
			//printf("err at set position %d\n", err);
			CFRelease(temp);

		}
		CFRelease(frontMostWindow);
		CFRelease(frontMostApp);

		centeredRecently = centeredResizedRecently = fulledRecently = halfedRecently = false;
		centeredRecently = true;
	}
}

-(void)centerAndResize:(NSEvent*)sender{

	if ([sender type] == NSKeyDown){

		if (timeoutTimer != nil) [timeoutTimer invalidate];
		timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeOutTime target:self selector:@selector(timeOut) userInfo:nil repeats:NO];

		AXValueRef temp;
		CGSize windowSize;
		CGPoint windowPosition;
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

		NSArray * screens = [NSScreen screens];
		int index = -1;
		int nextIndex = -1;
		for (int i = 0; i < [screens count]; i++){
			NSScreen * s = [screens objectAtIndex:i];
			NSRect f = [s frame];
			NSPoint p = NSMakePoint(windowPosition.x + windowSize.width / 2 , flip(windowPosition.y + windowSize.height / 2) );
			//NSLog(@"Point %@ in Rect %@", NSStringFromPoint(p), NSStringFromRect(f));
			if (  NSPointInRect ( p , NSInsetRect(f, 0, 0 ) ) ){
				index = i;
			}
		}

		if (index != -1){

			if (centeredResizedRecently){ //user pressed 2 times in a row center, so jump center across screens
				index = index + 1;
				if (index >= [screens count]) {
					index = 0;
				}
			}

			//NSLog(@"center resize %d", index);

			float screenWindowSizePercentX = 0.6;
			float screenWindowSizePercentY = 0.95;
			NSScreen * screen = [screens objectAtIndex:index];
			NSPoint screenPos = [screen visibleFrame].origin;
			NSSize screenSize = [screen visibleFrame].size;

			screenPos.x += screenSize.width * 0.5 - screenSize.width * (screenWindowSizePercentX) * 0.5;
			screenPos.y = flip(screenSize.height + screenPos.y) + screenSize.height * 0.5 * (1-screenWindowSizePercentY);

			screenSize.width *= screenWindowSizePercentX;
			screenSize.height *= screenWindowSizePercentY;

			AXError err;

			temp = AXValueCreate(kAXValueCGSizeType, &screenSize);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXSizeAttribute, temp);
			CFRelease(temp);

			if(err != 0){ //if we couldnt resize win, take in account so that centering at least still works
				//NSLog(@"fix");
				screenPos.x = [screen visibleFrame].origin.x + [screen visibleFrame].size.width * 0.5 - windowSize.width * 0.5;
				screenPos.y = flip([screen visibleFrame].origin.y + [screen visibleFrame].size.height) + [screen visibleFrame].size.height * 0.5- windowSize.height * 0.5 ;
			}

			temp = AXValueCreate(kAXValueCGPointType, &screenPos);
			err = AXUIElementSetAttributeValue(frontMostWindow, kAXPositionAttribute, temp);
			CFRelease(temp);

		}
		CFRelease(frontMostWindow);
		CFRelease(frontMostApp);

		centeredRecently = centeredResizedRecently = fulledRecently = halfedRecently = false;
		centeredResizedRecently = true;
	}
}


-(IBAction)growYTrigger:(NSEvent*)sender;{
	currentAction = GROW_U;
	[self handleTrigger:sender];
}

-(IBAction)shrinkYTrigger:(NSEvent*)sender;{
	currentAction = GROW_D;
	[self handleTrigger:sender];
}

-(IBAction)growXTrigger:(NSEvent*)sender;{
	currentAction = GROW_R;
	[self handleTrigger:sender];
}

-(IBAction)shrinkXTrigger:(NSEvent*)sender;{
	currentAction = GROW_L;
	[self handleTrigger:sender];
}


-(IBAction)growY:(NSEvent*)sender;{
	[self performSelector:@selector(resizeWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:0], @"x",
	  [NSNumber numberWithInt:offsetNow], @"y",
	  nil]
	afterDelay:0.00];
}

-(IBAction)shrinkY:(NSEvent*)sender;{
	[self performSelector:@selector(resizeWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:0], @"x",
	  [NSNumber numberWithInt:-offsetNow], @"y",
	  nil]
   afterDelay:0.00];
}

-(IBAction)growX:(NSEvent*)sender;{
	[self performSelector:@selector(resizeWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:offsetNow], @"x",
	  [NSNumber numberWithInt:0], @"y",
	  nil]
			   afterDelay:0.00];
}

-(IBAction)shrinkX:(NSEvent*)sender;{
	[self performSelector:@selector(resizeWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:-offsetNow], @"x",
	  [NSNumber numberWithInt:0], @"y",
	  nil]
			   afterDelay:0.00];
}


-(IBAction)moveUp:(NSEvent*)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
		[NSNumber numberWithBool:true], @"relative", 
		[NSNumber numberWithInt:0], @"x", 
		[NSNumber numberWithInt:-offsetNow], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)moveDown:(NSEvent*)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:true], @"relative", 
	  [NSNumber numberWithInt:0], @"x", 
	  [NSNumber numberWithInt:offsetNow], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)moveRight:(NSEvent*)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:true], @"relative", 
	  [NSNumber numberWithInt:offsetNow], @"x", 
	  [NSNumber numberWithInt:00], @"y", nil]
			   afterDelay:0.00];
}

-(IBAction)moveLeft:(NSEvent*)sender;{
	[self performSelector:@selector(moveWindow:) withObject:
	 [NSDictionary dictionaryWithObjectsAndKeys: 
	  [NSNumber numberWithBool:true], @"relative", 
	  [NSNumber numberWithInt:-offsetNow], @"x",
	  [NSNumber numberWithInt:0], @"y", nil]
			   afterDelay:0.00];
}


-(IBAction)moveLeftTrigger:(NSEvent*)sender;{
	currentAction = MOVE_L;
	[self handleTrigger:sender];
}

-(IBAction)moveRightTrigger:(NSEvent*)sender;{
	currentAction = MOVE_R;
	[self handleTrigger:sender];
}


-(IBAction)moveUpTrigger:(NSEvent*)sender;{
	currentAction = MOVE_U;
	[self handleTrigger:sender];
}


-(IBAction)moveDownTrigger:(NSEvent*)sender;{
	currentAction = MOVE_D;
	[self handleTrigger:sender];
}


-(IBAction)pushUp:(NSEvent*)sender;{
	if ([sender type] == NSKeyDown){
		[self performSelector:@selector(moveWindow:) withObject:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithBool:false], @"relative",
		  @"N", @"abosolutePosition", nil]
				   afterDelay:0.00];
	}
}

-(IBAction)pushDown:(NSEvent*)sender;{
	if ([sender type] == NSKeyDown){
		[self performSelector:@selector(moveWindow:) withObject:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithBool:false], @"relative",
		  @"S", @"abosolutePosition", nil]
		afterDelay:0.00];
	}
}

-(IBAction)pushRight:(NSEvent*)sender;{
	if ([sender type] == NSKeyDown){
		[self performSelector:@selector(moveWindow:) withObject:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithBool:false], @"relative",
		  @"E", @"abosolutePosition", nil]
				   afterDelay:0.00];
	}
}

-(IBAction)pushLeft:(NSEvent*)sender;{
	if ([sender type] == NSKeyDown){
		[self performSelector:@selector(moveWindow:) withObject:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithBool:false], @"relative",
		  @"W", @"abosolutePosition", nil]
				   afterDelay:0.00];
	}
}

@end
