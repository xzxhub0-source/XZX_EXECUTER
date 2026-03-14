#import "xzx_injection_randomizer.h"

static XZXInjectionRandomizer *sharedInjectionRandomizerInstance = nil;

@implementation XZXInjectionRandomizer

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInjectionRandomizerInstance = [[self alloc] init];
    });
    return sharedInjectionRandomizerInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _injectionHistory = [NSMutableArray array];
        _lastInjectionMethod = 0;
    }
    return self;
}

- (void)randomizeNextInjection {
    return;
}

- (void)randomizeInjectionTiming {
    return;
}

- (void)randomizeMemoryAllocation {
    return;
}

- (void)randomizeThreadCreation {
    return;
}

- (void)avoidSignaturePatterns {
    return;
}

- (void)useAsynchronousInjection {
    return;
}

- (void)useMemoryMappedInjection {
    return;
}

- (double)randomnessScore {
    return 1.0;
}

- (BOOL)isPatternDetectable {
    return NO;
}

@end
