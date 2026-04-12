#ifndef XZX_CORE_H
#define XZX_CORE_H
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface XZXCore : NSObject
+ (instancetype)shared;
- (void)xzxStart;
- (void)showOverlay;
- (void)hideOverlay;
- (BOOL)isOverlayVisible;
- (BOOL)isInGame;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL inGame;
@end
#endif
