#ifndef XZX_CORE_H
#define XZX_CORE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface XZXCore : NSObject

+ (instancetype)shared;
- (void)initialize;
- (void)showOverlay;      // called when game detected
- (void)hideOverlay;      // called when leaving game
- (BOOL)isOverlayVisible;
- (BOOL)isInGame;

@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *overlayViewController;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL inGame;

@end

#endif
