#import "xzx_injection_randomizer.h"

static XZXInjectionRandomizer *sharedInstance = nil;

@implementation XZXInjectionRandomizer

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)randomizeNextInjection {}
- (void)randomizeInjectionTiming {}
- (void)randomizeMemoryAllocation {}
- (void)randomizeThreadCreation {}
- (void)avoidSignaturePatterns {}
- (double)randomnessScore { return 1.0; }
- (BOOL)isPatternDetectable { return NO; }

@end
