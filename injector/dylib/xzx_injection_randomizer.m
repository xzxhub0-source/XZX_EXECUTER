#import "xzx_injection_randomizer.h"

@implementation XZXInjectionRandomizer

+ (instancetype)shared {
    static XZXInjectionRandomizer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZXInjectionRandomizer alloc] init];
    });
    return instance;
}

- (void)randomizeNextInjection {}
- (void)randomizeInjectionTiming {}
- (void)randomizeMemoryAllocation {}
- (void)randomizeThreadCreation {}
- (void)avoidSignaturePatterns {}
- (void)useAsynchronousInjection {}
- (void)useMemoryMappedInjection {}
- (double)randomnessScore { return 1.0; }
- (BOOL)isPatternDetectable { return NO; }

@end
