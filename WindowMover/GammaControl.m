//
//  GammaControl.m
//  MoveMyWindow
//
//  Created by Oriol Ferrer Mesià on 04/08/13.
//
//

#import "GammaControl.h"

@implementation GammaControl

+(void) setGamma:(float) newGamma{

	//NSLog(@"setGamma %f\n", newGamma);
	CGGammaValue table[] = {0, newGamma,  1};
	CGDirectDisplayID displays[MAX_DISPLAYS];
    uint32_t numDisplays;
    uint32_t i;

    CGGetActiveDisplayList(MAX_DISPLAYS, displays, &numDisplays);

    for(i=0; i<numDisplays; i++){
		//CGSetDisplayTransferByTable(CGMainDisplayID(), sizeof(table) / sizeof(table[0]), table, table, table);
		CGSetDisplayTransferByTable(displays[i], sizeof(table) / sizeof(table[0]), table, table, table);
    }
}


+(void) setGammaInverted:(float) newGamma{

	//NSLog(@"setGammaInverted %f\n", newGamma);
	CGGammaValue table[] = {1, newGamma,  0};
	CGDirectDisplayID displays[MAX_DISPLAYS];
    uint32_t numDisplays;
    uint32_t i;

    CGGetActiveDisplayList(MAX_DISPLAYS, displays, &numDisplays);

    for(i=0; i<numDisplays; i++){
		//CGSetDisplayTransferByTable(CGMainDisplayID(), sizeof(table) / sizeof(table[0]), table, table, table);
		CGSetDisplayTransferByTable(displays[i], sizeof(table) / sizeof(table[0]), table, table, table);
    }
}

@end
