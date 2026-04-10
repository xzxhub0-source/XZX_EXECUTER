#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static XZXCore *sharedCore = nil;

@interface XZXCore ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) NSTimer  *watchdogTimer;
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
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;

    InitLua();
    NSLog(@"[XZX] Lua initialized");

    // Wait 12 seconds — clears loading screen completely before we show anything
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self showOverlay];
        [self startWatchdog];
        _inGame = YES;
    });
}

// Watchdog: every 3 seconds check if our window got killed and revive it
- (void)startWatchdog {
    _watchdogTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                      target:self
                                                    selector:@selector(watchdogTick)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)watchdogTick {
    if (!_overlayWindow || _overlayWindow.hidden) {
        NSLog(@"[XZX] Watchdog: overlay gone — reviving");
        [self showOverlay];
    }
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    // Fallback: grab any connected scene
    if (!scene) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }
    if (!scene) { NSLog(@"[XZX] No scene"); return; }

    // Rebuild the window if the scene changed (happens during load→game transition)
    if (_overlayWindow && _overlayWindow.windowScene != scene) {
        NSLog(@"[XZX] Scene changed — rebuilding window");
        _overlayWindow = nil;
    }

    if (!_overlayWindow) {
        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) { NSLog(@"[XZX] VC not found"); return; }

        _overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        _overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        _overlayWindow.backgroundColor = [UIColor clearColor];
        _overlayWindow.rootViewController = vc;
    }

    _overlayWindow.hidden = NO;
    [_overlayWindow makeKeyAndVisible];
    NSLog(@"[XZX] Overlay shown");
}

- (void)hideOverlay {
    _overlayWindow.hidden = YES;
    // Stop watchdog so user-triggered hide stays hidden
    [_watchdogTimer invalidate];
    _watchdogTimer = nil;
    NSLog(@"[XZX] Overlay hidden by user");
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
