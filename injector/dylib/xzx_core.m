#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static BOOL uiCreated = NO;

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
        _inGame = NO;
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
        [self startGameMonitoring];
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:3.0];
        while (YES) {
            @autoreleasepool {
                BOOL inGame = [self isInGameCheck];
                if (inGame && !self.inGame) {
                    self.inGame = YES;
                    NSLog(@"[XZX] Game detected");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                                       dispatch_get_main_queue(), ^{
                            [self showOverlay];
                        });
                    });
                } else if (!inGame && self.inGame) {
                    self.inGame = NO;
                    NSLog(@"[XZX] Left game");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)findRobloxViewInView:(UIView *)view {
    NSString *cn = NSStringFromClass([view class]);
    if ([cn containsString:@"Metal"] ||
        [cn containsString:@"RBX"] ||
        [cn containsString:@"Roblox"] ||
        [cn containsString:@"GameView"] ||
        [cn containsString:@"RBXUI"]) {
        return YES;
    }
    for (UIView *sub in view.subviews) {
        if ([self findRobloxViewInView:sub]) return YES;
    }
    return NO;
}

- (BOOL)isInGameCheck {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if ([self findRobloxViewInView:window]) {
                NSLog(@"[XZX] Roblox render view found");
                return YES;
            }
        }

        Class dm = NSClassFromString(@"RobloxDataModel");
        if (dm) {
            SEL s = NSSelectorFromString(@"sharedDataModel");
            if ([dm respondsToSelector:s]) {
                id model = ((id(*)(id,SEL))objc_msgSend)((id)dm, s);
                if (model) {
                    SEL ps = NSSelectorFromString(@"placeId");
                    if ([model respondsToSelector:ps]) {
                        id placeId = ((id(*)(id,SEL))objc_msgSend)(model, ps);
                        if (placeId && [placeId intValue] != 0) return YES;
                    }
                }
            }
        }

        UIWindowScene *scene = (UIWindowScene *)
            [UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        UIViewController *root = scene.keyWindow.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        NSString *cn = NSStringFromClass([root class]);
        if ([cn containsString:@"Gameplay"] ||
            [cn containsString:@"InGame"] ||
            [cn containsString:@"PlayView"] ||
            [cn containsString:@"RBX"]) {
            return YES;
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection exception: %@", e);
    }
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = (UIWindowScene *)
            [UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) {
            NSLog(@"[XZX] No scene");
            return;
        }

        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) {
            NSLog(@"[XZX] ERROR: Could not find MainViewController class");
            return;
        }

        if (!self.overlayWindow) {
            self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
            self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
            self.overlayWindow.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = vc;
        }

        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = YES;
        NSLog(@"[XZX] Overlay hidden");
    });
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
