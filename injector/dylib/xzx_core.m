#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;

// Show after 3 seconds of being in game (avoid menu false positives)
// Hide after 20 seconds of being out of game (survive loading screens)
static const NSInteger kDebounceShow = 3;
static const NSInteger kDebounceHide = 20;

@interface XZXCore ()
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) NSTimer *rebuildTimer;
@end

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sharedCore = [[self alloc] init]; });
    return sharedCore;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _overlayWindow  = nil;
        _isInitialized  = NO;
        _inGame         = NO;
        _positiveCount  = 0;
        _negativeCount  = 0;
        monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        // Start auto-rebuild timer (checks every 2 seconds)
        _rebuildTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:self
                                                       selector:@selector(rebuildIfNeeded)
                                                       userInfo:nil
                                                        repeats:YES];
        
        [self startGameMonitoring];
    });
}

// Auto-rebuild: if overlay window is gone or hidden, recreate it
- (void)rebuildIfNeeded {
    if (!self.inGame) return; // Only rebuild when we're supposed to be in game
    
    BOOL needsRebuild = NO;
    
    if (!_overlayWindow) {
        needsRebuild = YES;
        NSLog(@"[XZX] Rebuild: overlayWindow is nil");
    } else if (_overlayWindow.hidden) {
        needsRebuild = YES;
        NSLog(@"[XZX] Rebuild: overlayWindow is hidden");
    } else if (!_overlayWindow.rootViewController) {
        needsRebuild = YES;
        NSLog(@"[XZX] Rebuild: rootViewController missing");
    } else if (!_overlayWindow.rootViewController.view.window) {
        needsRebuild = YES;
        NSLog(@"[XZX] Rebuild: view not in window hierarchy");
    }
    
    if (needsRebuild) {
        // Destroy old window
        _overlayWindow.hidden = YES;
        _overlayWindow = nil;
        
        // Recreate
        [self showOverlay];
    }
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait 15 seconds – fully clears the Roblox loading screen and menu detection
        [NSThread sleepForTimeInterval:15.0];
        NSLog(@"[XZX] Detection started");

        while (YES) {
            @autoreleasepool {
                __block BOOL inGame = NO;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    inGame = [self isGameEngineActive];
                });

                if (inGame) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                    if (self.positiveCount == 1) {
                        NSLog(@"[XZX] In-game signals detected, confirming...");
                    }
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                if (!self.inGame && self.positiveCount >= kDebounceShow) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] ✅ Game confirmed — showing UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                } else if (self.inGame && self.negativeCount >= kDebounceHide) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] ❌ Left game — hiding UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

// Detection: Metal rendering + fullscreen (status bar hidden) + very few buttons
// Menu has 15+ buttons, in-game has 3-5 buttons
- (BOOL)isGameEngineActive {
    @try {
        BOOL statusBarHidden = NO;
        NSInteger buttonCount = 0;
        BOOL hasMetalLayer = NO;

        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;

            if (ws.statusBarManager.statusBarHidden) {
                statusBarHidden = YES;
            }

            for (UIWindow *window in ws.windows) {
                buttonCount += [self countButtonsInView:window];
                if ([self viewHasMetalLayer:window]) hasMetalLayer = YES;
            }
        }

        // Log what we see (helps debug)
        if (hasMetalLayer) {
            NSLog(@"[XZX] Metal: YES, statusBarHidden: %d, buttons: %ld", statusBarHidden, (long)buttonCount);
        }

        // In-game = Metal present + status bar hidden + less than 6 buttons
        return (hasMetalLayer && statusBarHidden && buttonCount < 6);
    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection error: %@", e);
    }
    return NO;
}

- (BOOL)viewHasMetalLayer:(UIView *)view {
    @try {
        if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        for (CALayer *sub in view.layer.sublayers ?: @[]) {
            if ([sub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            for (CALayer *subsub in sub.sublayers ?: @[]) {
                if ([subsub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            }
        }
        for (UIView *sub in view.subviews) {
            if ([self viewHasMetalLayer:sub]) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (NSInteger)countButtonsInView:(UIView *)view {
    NSInteger count = 0;
    @try {
        if ([view isKindOfClass:[UIButton class]]) count++;
        if (count > 10) return count; // Early exit, we already know it's menu
        for (UIView *sub in view.subviews) {
            count += [self countButtonsInView:sub];
            if (count > 10) return count;
        }
    } @catch (NSException *e) {}
    return count;
}

- (void)showOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Don't show if we're not in game
        if (!self.inGame) {
            NSLog(@"[XZX] showOverlay called but not in game — ignoring");
            return;
        }
        
        if (_overlayWindow && !_overlayWindow.hidden && _overlayWindow.rootViewController) {
            return; // Already visible
        }
        
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }
        if (!scene) { NSLog(@"[XZX] No scene"); return; }
        
        if (_overlayWindow && _overlayWindow.windowScene != scene) {
            _overlayWindow = nil;
        }
        
        if (!_overlayWindow) {
            UIViewController *vc = [[XZXMainViewController alloc] init];
            if (!vc) { NSLog(@"[XZX] VC not found"); return; }
            _overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
            _overlayWindow.windowLevel = UIWindowLevelAlert + 1;
            _overlayWindow.backgroundColor = [UIColor clearColor];
            _overlayWindow.rootViewController = vc;
        }
        
        _overlayWindow.hidden = NO;
        [_overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_overlayWindow) {
            _overlayWindow.hidden = YES;
            NSLog(@"[XZX] Overlay hidden");
        }
    });
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
