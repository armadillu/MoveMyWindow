//
//  GammaControl.h
//  MoveMyWindow
//
//  Created by Oriol Ferrer Mesià on 04/08/13.
//
//

#define MAX_DISPLAYS 12
#import <Foundation/Foundation.h>

@interface GammaControl : NSObject

+ (void)setGamma:(float)f;
+ (void)setGammaInverted:(float)f;

@end
