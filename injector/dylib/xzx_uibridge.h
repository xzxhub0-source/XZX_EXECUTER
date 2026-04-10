#ifndef XZX_UIBRIDGE_H
#define XZX_UIBRIDGE_H

#import <Foundation/Foundation.h>

@interface XZXUIBridge : NSObject
+ (instancetype)shared;
- (void)createInGameUI;
- (void)destroyInGameUI;
- (void)showUI;
- (void)hideUI;
- (void)onScriptSubmitted:(NSString *)script;
@end

#endif
