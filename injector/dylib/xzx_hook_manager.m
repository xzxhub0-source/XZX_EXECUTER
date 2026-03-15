#import "xzx_hook_manager.h"

@implementation XZXHookManager

+ (instancetype)shared {
    static XZXHookManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZXHookManager alloc] init];
    });
    return instance;
}

- (void)initializeHookSystem {}
- (void)addHook:(NSString *)functionName original:(void *)original hook:(void *)hook {}
- (void)removeHook:(NSString *)functionName {}
- (void)restoreAllFunctions {}
- (BOOL)areHooksExposed { return NO; }
- (void)hideFromAdonis {}
- (void)spoofConnectionList {}
- (void)randomizeHookOrder {}
- (double)exposureRatio { return 0.0; }
- (void *)cloneFunction:(void *)original { return original; }
- (void)restoreFunction:(NSString *)functionName {}
- (NSString *)getFunctionHash:(void *)function { return @""; }
- (NSArray *)getConnections:(NSString *)signal { return @[]; }
- (void)fireSignal:(NSString *)signal withArguments:(NSArray *)args {}
- (NSArray *)getSignalArguments:(NSString *)signal { return @[]; }
- (BOOL)canSignalReplicate:(NSString *)signal { return YES; }
- (void)replicateSignal:(NSString *)signal withArguments:(NSArray *)args {}

@end
