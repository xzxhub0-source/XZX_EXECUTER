#ifndef XZX_CORE_H
#define XZX_CORE_H

#import <Foundation/Foundation.h>

@interface XZXCore : NSObject
+ (instancetype)shared;
- (void)initialize;
- (void)showOverlay;   // now creates in-game UI
- (void)hideOverlay;   // destroys it
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL inGame;
@end

#endif
