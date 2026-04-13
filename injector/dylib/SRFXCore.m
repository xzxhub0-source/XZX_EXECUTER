#import "SRFXCore.h"
#import "SRFXMainViewController.h"
#import <QuartzCore/QuartzCore.h>
#include "Core/SRFXLua.h"

static SRFXCore *instance = nil;
static const NSInteger kDebounce = 3;

@implementation SRFXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _inGame = NO;
        _uiWindow = nil;
        _positiveCount = 0;
        _negativeCount = 0;
    }
    return self;
}

- (void)start {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        SRFXLuaInit();
        [self startGameDetection];
    });
}

- (void)startGameDetection {
    __weak typeof(self) weak = self;
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:1.2
                                                      repeats:YES
                                                        block:^(NSTimer *t) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strong = weak;
            if (!strong) { [t invalidate]; return; }
            [strong pollGameState];
        });
    }];
}

- (void)pollGameState {
    BOOL nowInGame = [self isInsideGame];

    if (nowInGame) { self.positiveCount++; self.negativeCount = 0; }
    else           { self.negativeCount++; self.positiveCount = 0; }

    if (!self.inGame && self.positiveCount >= kDebounce) {
        self.inGame = YES;
        self.positiveCount = 0;
        [self showUI];
    } else if (self.inGame && self.negativeCount >= kDebounce) {
        self.inGame = NO;
        self.negativeCount = 0;
        [self hideUI];
    }
}

- (BOOL)isInsideGame {
    @try {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive) continue;

            BOOL statusBarHidden = windowScene.statusBarManager.statusBarHidden;
            BOOL hasMetal = NO;
            NSInteger buttonCount = 0;

            for (UIWindow *window in windowScene.windows) {
                if (window == self.uiWindow) continue;
                if (!hasMetal) hasMetal = [self viewHasMetalLayer:window];
                if (buttonCount < 20) buttonCount += [self countButtonsInView:window];
            }

            if (hasMetal && statusBarHidden && buttonCount < 6) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (BOOL)viewHasMetalLayer:(UIView *)view {
    @try {
        if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        for (CALayer *sub in view.layer.sublayers ?: @[]) {
            if ([sub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            for (CALayer *s2 in sub.sublayers ?: @[])
                if ([s2 isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        }
        for (UIView *sub in view.subviews)
            if ([self viewHasMetalLayer:sub]) return YES;
    } @catch (NSException *e) {}
    return NO;
}

- (NSInteger)countButtonsInView:(UIView *)view {
    NSInteger n = 0;
    @try {
        if ([view isKindOfClass:[UIButton class]]) n++;
        if (n >= 20) return n;
        for (UIView *sub in view.subviews) {
            n += [self countButtonsInView:sub];
            if (n >= 20) return n;
        }
    } @catch (NSException *e) {}
    return n;
}

- (void)showUI {
    if (!self.inGame) return;
    if (self.uiWindow && !self.uiWindow.hidden) return;

    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{ [self showUI]; });
        return;
    }

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s; break;
        }
    }
    if (!scene)
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    if (!scene) return;

    if (!self.uiWindow) {
        SRFXMainViewController *vc = [[SRFXMainViewController alloc] init];
        self.uiWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.uiWindow.windowLevel = UIWindowLevelAlert + 5;
        self.uiWindow.backgroundColor = UIColor.clearColor;
        self.uiWindow.rootViewController = vc;
        self.uiWindow.hidden = YES;
    }

    self.uiWindow.hidden = NO;
    [self.uiWindow makeKeyAndVisible];
}

- (void)hideUI {
    if (!self.uiWindow) return;
    self.uiWindow.hidden = YES;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w != self.uiWindow && !w.isKeyWindow) {
                    [w makeKeyWindow];
                    return;
                }
            }
        }
    }
}

- (void)dealloc {
    [self.checkTimer invalidate];
    self.checkTimer = nil;
}

@end
