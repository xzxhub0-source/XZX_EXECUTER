#ifndef XZX_CORE_H
#define XZX_CORE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface XZXCore : NSObject

+ (instancetype)shared;
- (void)initialize;
- (void)showOverlay;
- (void)hideOverlay;
- (void)resizeOverlayToNormal;  // NEW: resize from tiny to normal
- (BOOL)isOverlayVisible;
- (BOOL)isInGame;
- (BOOL)viewHasMetalLayer:(UIView *)view;

@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *overlayViewController;  // NEW: store reference
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL inGame;

@end

#endif
