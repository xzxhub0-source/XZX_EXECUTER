#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static XZXCore *sharedCore = nil;

@interface XZXCore ()
@property (nonatomic, strong) UIWindow *overlayWindow;  // redeclare to make ivar accessible
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
        self.overlayWindow  = nil;
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
    // Wait 12 seconds, then show overlay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self showOverlay];
        _inGame = YES;
    });
}

- (void)showOverlay {
    if (self.overlayWindow && !self.overlayWindow.hidden) return;

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

    if (self.overlayWindow && self.overlayWindow.windowScene != scene) {
        self.overlayWindow = nil;
    }

    if (!self.overlayWindow) {
        XZXMainViewController *vc = [[XZXMainViewController alloc] init];
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.rootViewController = vc;
    }

    self.overlayWindow.hidden = NO;
    [self.overlayWindow makeKeyAndVisible];
    NSLog(@"[XZX] Overlay shown");
}

- (void)hideOverlay {
    self.overlayWindow.hidden = YES;
    NSLog(@"[XZX] Overlay hidden");
}

- (BOOL)isOverlayVisible { return self.overlayWindow && !self.overlayWindow.hidden; }
- (BOOL)isInGame         { return _inGame; }

@end
