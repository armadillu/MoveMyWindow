//
//  AppDelegate.h
//  WindowMover
//
//  Created by Oriol Ferrer Mesià on 12/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDHotKeyCenter.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>{

	DDHotKeyCenter * keys;
	
	NSStatusItem*	_statusItem;
	NSString * lastAbsoluteMove;
	NSTimer * timeoutTimer;
	IBOutlet NSMenu * menu;

}

-(IBAction)moveUp:(id)sender;
-(IBAction)moveDown:(id)sender;
-(IBAction)moveRight:(id)sender;
-(IBAction)moveLeft:(id)sender;

-(IBAction)pushUp:(id)sender;

- (void) registerKeys;
- (void) unregisterKeys;

@property (assign) IBOutlet NSMenu *menu;

@end
