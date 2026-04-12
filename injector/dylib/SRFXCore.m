#import "SRFXCore.h"
#import "SRFXMainViewController.h"
#include "Core/SRFXLua.h"

static SRFXCore *instance = nil;

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
    SRFXLuaInit();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [self startGameDetection];
    });
}

- (void)startGameDetection {
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:1.2
                                                      repeats:YES
                                                        block:^(NSTimer *timer) {
        BOOL nowInGame = [self isInsideGame];
        if (nowInGame != self.inGame) {
            self.inGame = nowInGame;
            if (self.inGame) {
                [self showUI];
            } else {
                [self hideUI];
            }
        }
    }];
}

- (BOOL)isInsideGame {
    UIWindow *keyWindow = nil;
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
    }
    if (!keyWindow) return NO;

    NSString *rootClass = NSStringFromClass([keyWindow.rootViewController class]);
    NSArray *gameSignatures = @[
        @"RBXGameViewController",
        @"GameViewController",
        @"RobloxGameController",
        @"RBXViewController",
        @"UIRemoteKeyboardWindow"
    ];

    for (NSString *sig in gameSignatures) {
        if ([rootClass containsString:sig]) return YES;
    }

    for (UIViewController *child in keyWindow.rootViewController.childViewControllers) {
        NSString *childClass = NSStringFromClass([child class]);
        if ([childClass containsString:@"Game"] ||
            [childClass containsString:@"RBX"] ||
            [childClass containsString:@"Place"]) {
            return YES;
        }
    }

    return NO;
}

- (void)showUI {
    if (self.uiWindow && !self.uiWindow.hidden) return;
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{ [self showUI]; });
        return;
    }

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) return;

    SRFXMainViewController *vc = [[SRFXMainViewController alloc] init];
    self.uiWindow = [[UIWindow alloc] initWithWindowScene:scene];
    self.uiWindow.windowLevel = UIWindowLevelAlert + 5;
    self.uiWindow.backgroundColor = UIColor.clearColor;
    self.uiWindow.rootViewController = vc;
    self.uiWindow.hidden = NO;
    [self.uiWindow makeKeyAndVisible];
}

- (void)hideUI {
    self.uiWindow.hidden = YES;
}

@end
