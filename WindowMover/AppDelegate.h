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

	enum WIN_ACTION{
		NOTHING = 0,
		MOVE_L,
		MOVE_R,
		MOVE_U,
		MOVE_D,
		GROW_L,
		GROW_R,
		GROW_U,
		GROW_D
	};

	DDHotKeyCenter * keys;
	
	NSStatusItem*	_statusItem;
	NSString * lastAbsoluteMove;
	bool centeredRecently;
	bool centeredResizedRecently;
	bool fulledRecently;
	NSTimer * timeoutTimer;
	NSTimer * updateTimer;
	IBOutlet NSMenu * menu;
	IBOutlet NSSlider * offsetSlider;
	
	float offset;
	float offsetNow;

	float timeOutTime;

	enum WIN_ACTION currentAction;
}

-(IBAction)moveUp:(NSEvent*)sender;
-(IBAction)moveDown:(NSEvent*)sender;
-(IBAction)moveRight:(NSEvent*)sender;
-(IBAction)moveLeft:(NSEvent*)sender;
-(IBAction)pushUp:(NSEvent*)sender;

-(IBAction)changeOffset:(id)sender;

- (void) registerKeys;
- (void) unregisterKeys;

@property (assign) IBOutlet NSMenu *menu;

@end
