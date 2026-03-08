#ifndef XZX_SECURITY_H
#define XZX_SECURITY_H

#import <Foundation/Foundation.h>

@interface XZXSecurity : NSObject
+ (instancetype)shared;
- (void)applyBypasses;
- (void)hideFromAdonis;
- (void)bypassUIchecks;
- (void)obfuscateMemory;
- (void)cleanHooks;

@property (nonatomic, assign) BOOL isHooked;
@property (nonatomic, strong) NSMutableDictionary *originalFunctions;
@end

#endif
