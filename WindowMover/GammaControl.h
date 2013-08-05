//
//  GammaControl.h
//  MoveMyWindow
//
//  Created by Oriol Ferrer Mesià on 04/08/13.
//
//

#define MAX_DISPLAYS			12
#define GAMMA_TABLE_SAMPLES		127

#ifndef MIN
#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#endif

#ifndef MAX
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#endif


#import <Foundation/Foundation.h>

@interface GammaControl : NSObject

+ (void)setGamma:(float)f;
+ (void)setGammaInverted:(float)f;

@end
