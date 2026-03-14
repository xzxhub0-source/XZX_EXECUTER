#ifndef XZX_HOOK_MANAGER_H
#define XZX_HOOK_MANAGER_H

#import <Foundation/Foundation.h>

@interface XZXHookManager : NSObject
+ (instancetype)shared;
- (void)initializeHookSystem;
- (void)addHook:(NSString *)functionName original:(void *)original hook:(void *)hook;
- (void)removeHook:(NSString *)functionName;
- (void)restoreAllFunctions;
- (BOOL)areHooksExposed;
- (void)hideFromAdonis;
- (void)spoofConnectionList;
- (void)randomizeHookOrder;
- (double)exposureRatio;
- (void *)cloneFunction:(void *)original;
- (NSString *)getFunctionHash:(void *)function;
- (NSArray *)getConnections:(NSString *)signal;
- (void)fireSignal:(NSString *)signal withArguments:(NSArray *)args;

@property (nonatomic, strong) NSMutableDictionary *hooks;
@property (nonatomic, strong) NSMutableDictionary *originalFunctions;
@property (nonatomic, strong) NSMutableArray *exposedHooks;
@end

#endif
