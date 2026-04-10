#ifndef XZX_CORE_H
#define XZX_CORE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface XZXCore : NSObject

+ (instancetype)shared;
- (void)initialize;
- (void)showOverlay;
- (void)hideOverlay;
- (BOOL)isOverlayVisible;
- (BOOL)isInGame;
- (BOOL)isActuallyInGame;  // NEW: checks placeId
- (BOOL)viewHasMetalLayer:(UIView *)view;

@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *overlayViewController;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL inGame;

@end

#endif
