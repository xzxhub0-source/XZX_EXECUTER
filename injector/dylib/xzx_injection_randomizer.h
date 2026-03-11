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
- (void)useAsynchronousInjection;
- (void)useMemoryMappedInjection;
- (void)useDynamicCodeGeneration;
- (void)obfuscateInjectionPoint;
- (double)randomnessScore;
- (BOOL)isPatternDetectable;
- (void)rotateInjectionMethod;
- (void)simulateLegitimateBehavior;

@property (nonatomic, assign) NSInteger lastInjectionMethod;
@property (nonatomic, strong) NSMutableArray *injectionHistory;
@property (nonatomic, strong) NSMutableDictionary *methodPatterns;
@end

#endif
