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
- (void)startGameMonitoring;
- (BOOL)isInGame;

@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL inGame;
@property (nonatomic, assign) BOOL overlayAllowed;  // NEW: strict gate

@end

#endif
