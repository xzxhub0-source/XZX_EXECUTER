#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
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
        _overlayWindow = nil;
        _isInitialized = NO;
        _inGame        = NO;
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    InitLua();
    NSLog(@"[XZX] Lua initialized");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self pollForGameState];
    });
}

- (void)pollForGameState {
    if (_inGame) return;
    if ([self isMenuVisible]) {
        NSLog(@"[XZX] Menu visible, waiting for game...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self pollForGameState];
        });
    } else {
        NSLog(@"[XZX] Game detected — showing overlay");
        _inGame = YES;
        [self showOverlay];
        [self startWatchdog];
    }
}

- (BOOL)isMenuVisible {
    @try {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *window in ws.windows) {
                if (window == _overlayWindow) continue;
                if ([self viewHasVisibleWebView:window]) return YES;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] isMenuVisible error: %@", e);
    }
    return NO;
}

- (BOOL)viewHasVisibleWebView:(UIView *)view {
    @try {
        if (view.isHidden || view.alpha < 0.01f) return NO;
        if ([view isKindOfClass:[WKWebView class]] &&
            view.bounds.size.width > 50 && view.bounds.size.height > 50) {
            NSLog(@"[XZX] Found WKWebView (%@)", NSStringFromCGRect(view.frame));
            return YES;
        }
        NSString *className = NSStringFromClass([view class]);
        if (([className containsString:@"WKWeb"] || [className containsString:@"WebView"]) &&
            view.bounds.size.width > 50) {
            NSLog(@"[XZX] Found WebView subclass: %@", className);
            return YES;
        }
        for (UIView *sub in view.subviews) {
            if ([self viewHasVisibleWebView:sub]) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (void)startWatchdog {
    [_watchdogTimer invalidate];
    _watchdogTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                      target:self
                                                    selector:@selector(watchdogTick)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)watchdogTick {
    if ([self isMenuVisible]) {
        if (_inGame) {
            NSLog(@"[XZX] Menu reappeared — hiding overlay");
            _inGame = NO;
            [self hideOverlay];
            [_watchdogTimer invalidate];
            _watchdogTimer = nil;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pollForGameState];
            });
        }
        return;
    }
    if (!_overlayWindow || _overlayWindow.hidden) {
        NSLog(@"[XZX] Watchdog: overlay gone — rebuilding");
        _overlayWindow = nil;
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
    if (!scene) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }
    if (!scene) { NSLog(@"[XZX] showOverlay: no scene"); return; }

    if (_overlayWindow && _overlayWindow.windowScene != scene) {
        _overlayWindow = nil;
    }

    if (!_overlayWindow) {
        XZXMainViewController *vc = [[XZXMainViewController alloc] init];
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
    NSLog(@"[XZX] Overlay hidden");
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
