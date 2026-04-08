#ifndef XZX_INJECTION_RANDOMIZER_H
#define XZX_INJECTION_RANDOMIZER_H

#import <Foundation/Foundation.h>

@interface XZXInjectionRandomizer : NSObject
+ (instancetype)shared;
- (void)randomizeNextInjection;
- (void)randomizeInjectionTiming;
- (void)randomizeMemoryAllocation;
- (void)randomizeThreadCreation;
- (void)avoidSignaturePatterns;
- (double)randomnessScore;
- (BOOL)isPatternDetectable;
@end

#endif
