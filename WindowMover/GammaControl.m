//
//  GammaControl.m
//  MoveMyWindow
//
//  Created by Oriol Ferrer Mesià on 04/08/13.
//
//

#import "GammaControl.h"

//rgb
static CGGammaValue originalGammaTables[MAX_DISPLAYS][3][GAMMA_TABLE_SAMPLES];


//http://www.flong.com/texts/code/shapers_bez/
float quadraticBezier (float x, float a, float b){
	// adapted from BEZMATH.PS (1993)
	// by Don Lancaster, SYNERGETICS Inc.
	// http://www.tinaja.com/text/bezmath.html

	float epsilon = 0.00001;
	a = MAX(0.0, MIN(1, a));
	b = MAX(0.0, MIN(1, b));
	if (a == 0.5){
		a += epsilon;
	}

	// solve t from x (an inverse operation)
	float om2a = 1.0f - 2.0f*a;
	float t = (sqrt(a*a + om2a*x) - a)/om2a;
	float y = (1.0f-2.0f*b)*(t*t) + (2.0f*b)*t;
	return y;
}

float symmetricQuadraticBezier(float x, float bulge /*[-1..1]*/){
	bulge = bulge/2.0f + 0.5f; //remap to [0..1]
	float a = bulge;
	float b = 1.0f-bulge;
	float r = quadraticBezier(x, a, b);
	return r;
}


@implementation GammaControl


+ (void)saveGammas{

	CGDirectDisplayID displays[MAX_DISPLAYS];
    uint32_t numDisplays;
    uint32_t i;

    CGGetActiveDisplayList(MAX_DISPLAYS, displays, &numDisplays);

	//assuming 256! //TODO!
	for(i=0; i<numDisplays; i++){

		CGTableCount count;
		CGDisplayErr error_code;
		error_code = CGGetDisplayTransferByTable(
													displays[i],
													(CGTableCount) GAMMA_TABLE_SAMPLES,
													&originalGammaTables[0][0][0],
													&originalGammaTables[0][0][1],
													&originalGammaTables[0][0][2],
													&count
												  );

	}
}


+(void) restoreGamma{

	CGDirectDisplayID displays[MAX_DISPLAYS];
    uint32_t numDisplays;
    uint32_t i;

    CGGetActiveDisplayList(MAX_DISPLAYS, displays, &numDisplays);

    for(i=0; i<numDisplays; i++){
		CGSetDisplayTransferByTable(displays[i], GAMMA_TABLE_SAMPLES, &originalGammaTables[0][0][0], &originalGammaTables[0][0][1], &originalGammaTables[0][0][2]);
    }
}


+(void) setGamma:(float) newGamma{

	//NSLog(@"setGamma %f\n", newGamma);
	CGGammaValue table[GAMMA_TABLE_SAMPLES];
	for(int i = 0; i < GAMMA_TABLE_SAMPLES; i++){
		table[i] = symmetricQuadraticBezier( i / (float)(GAMMA_TABLE_SAMPLES - 1), newGamma*2 - 1);
	}
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
