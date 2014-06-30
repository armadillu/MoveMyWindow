//
//  AppDelegate.h
//  WindowMover
//
//  Created by Oriol Ferrer Mesià on 12/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDHotKeyCenter.h"
#include "GammaControl.h"


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
	bool halfedRecently;
	NSTimer * timeoutTimer;
	NSTimer * updateTimer;
	IBOutlet NSMenu * menu;
	IBOutlet NSSlider * offsetSlider;
	IBOutlet NSSlider * gammaSlider;
	IBOutlet NSSlider * accSlider;


	IBOutlet NSButton * gammaInvertToggle;

	IBOutlet NSView * gammaView;
	IBOutlet NSMenuItem* gammaMenuItem;

	IBOutlet NSView * speedView;
	IBOutlet NSMenuItem* speedMenuItem;

	IBOutlet NSView * accView;
	IBOutlet NSMenuItem* accMenuItem;

	double offset;
	double offsetNow;
	double acc;

	float timeOutTime;

	enum WIN_ACTION currentAction;
}

-(IBAction)moveUp:(NSEvent*)sender;
-(IBAction)moveDown:(NSEvent*)sender;
-(IBAction)moveRight:(NSEvent*)sender;
-(IBAction)moveLeft:(NSEvent*)sender;
-(IBAction)pushUp:(NSEvent*)sender;

-(IBAction)changeOffset:(id)sender;
-(IBAction)changeAcc:(id)sender;


-(IBAction)setGamma:(id)sender;
-(IBAction)setGammaInvert:(id)sender;
-(IBAction)resetGamma:(id)sender;


- (void) registerKeys;
- (void) unregisterKeys;

@end
