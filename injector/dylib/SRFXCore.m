#import "SRFXCore.h"
#import "SRFXMainViewController.h"
#import "Core/SRFXLua.h"
#import <QuartzCore/QuartzCore.h>

static SRFXCore *instance = nil;
static const NSInteger kDebounce = 3;
static NSInteger positiveCount = 0;
static NSInteger negativeCount = 0;

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
    if (nowInGame) { positiveCount++; negativeCount = 0; }
    else           { negativeCount++; positiveCount = 0; }
    if (!self.inGame && positiveCount >= kDebounce) {
        self.inGame = YES;
        positiveCount = 0;
        [self showUI];
    } else if (self.inGame && negativeCount >= kDebounce) {
        self.inGame = NO;
        negativeCount = 0;
        [self hideUI];
    }
}

- (BOOL)isInsideGame {
    @try {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            if (ws.statusBarManager.statusBarHidden) {
                for (UIWindow *w in ws.windows) {
                    if (w == self.uiWindow) continue;
                    if ([self viewHasMetalLayer:w]) return YES;
                }
            }
        }
    } @catch (NSException *e) {}
    return NO;
}

- (BOOL)viewHasMetalLayer:(UIView *)view {
    return [self viewHasMetalLayer:view depth:0];
}

- (BOOL)viewHasMetalLayer:(UIView *)view depth:(int)depth {
    if (depth > 6) return NO;
    if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
    for (CALayer *sub in view.layer.sublayers)
        if ([sub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
    for (UIView *sub in view.subviews)
        if ([self viewHasMetalLayer:sub depth:depth + 1]) return YES;
    return NO;
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
