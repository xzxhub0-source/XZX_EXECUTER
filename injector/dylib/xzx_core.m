#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL monitorActive = NO;
static const NSInteger kDebounce = 2;

@interface XZXCore ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
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
    InitLua();
    NSLog(@"[XZX] Lua initialized");
    [self startPolling];
}

- (void)startPolling {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self pollOnce];
    });
}

- (void)pollOnce {
    BOOL inGame = [self isInGameCheck];

    if (inGame) {
        self.positiveCount++;
        self.negativeCount = 0;
    } else {
        self.negativeCount++;
        self.positiveCount = 0;
    }

    if (!self.inGame && self.positiveCount >= kDebounce) {
        self.inGame = YES;
        self.positiveCount = 0;
        NSLog(@"[XZX] In-game confirmed — showing UI");
        [self showOverlay];
    } else if (self.inGame && self.negativeCount >= kDebounce) {
        self.inGame = NO;
        self.negativeCount = 0;
        NSLog(@"[XZX] Left game — hiding UI");
        [self hideOverlay];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self pollOnce];
    });
}

// FIXED: Use WKWebView detection (menu has webview, game doesn't)
// Also uses iterative BFS with a node cap to avoid stack overflow (BUG 3)
- (BOOL)isInGameCheck {
    @try {
        __block BOOL hasWebView = NO;

        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *window in ws.windows) {
                if (window == _overlayWindow) continue;
                if ([self hasVisibleWebView:window]) {
                    hasWebView = YES;
                    break;
                }
            }
            if (hasWebView) break;
        }

        // In-game = no visible WKWebView (menu always has one)
        return !hasWebView;
    } @catch (NSException *e) {
        NSLog(@"[XZX] isInGameCheck error: %@", e);
    }
    return NO;
}

- (BOOL)hasVisibleWebView:(UIView *)root {
    if (!root) return NO;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    NSUInteger maxNodes = 2000;
    NSUInteger index = 0;

    while (index < queue.count && index < maxNodes) {
        UIView *view = queue[index];
        index++;

        @try {
            if (view.isHidden || view.alpha < 0.01) continue;
            if ([view isKindOfClass:[WKWebView class]] &&
                view.bounds.size.width > 50 && view.bounds.size.height > 50) {
                NSLog(@"[XZX] Found visible WKWebView: %@", NSStringFromCGRect(view.frame));
                return YES;
            }
            NSString *className = NSStringFromClass([view class]);
            if (([className containsString:@"WKWeb"] || [className containsString:@"WebView"]) &&
                view.bounds.size.width > 50) {
                NSLog(@"[XZX] Found WebView subclass: %@", className);
                return YES;
            }
            for (UIView *sub in view.subviews) {
                if (queue.count < maxNodes) [queue addObject:sub];
            }
        } @catch (NSException *e) {}
    }
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s; break;
        }
    }
    if (!scene) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s; break;
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
- (BOOL)isInGame         { return _inGame; }

@end
