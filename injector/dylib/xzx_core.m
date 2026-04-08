#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;

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
    InitLua();
    NSLog(@"[XZX] Initialized, watching for game...");
    [self startGameMonitoring];
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait for Roblox itself to finish launching
        [NSThread sleepForTimeInterval:3.0];

        while (YES) {
            @autoreleasepool {
                BOOL inGame = [self isInGameCheck];

                if (inGame && !self.inGame) {
                    self.inGame = YES;
                    NSLog(@"[XZX] CAMetalLayer detected — in game");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Small delay so Roblox render target is fully ready
                        dispatch_after(
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                            dispatch_get_main_queue(), ^{
                                [self showOverlay];
                            });
                    });
                } else if (!inGame && self.inGame) {
                    self.inGame = NO;
                    NSLog(@"[XZX] CAMetalLayer gone — left game");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

// KEY METHOD — CAMetalLayer only exists when Roblox is rendering a 3D game world.
// It is never present on the Roblox home screen, lobby, or loading screen.
// CAMetalLayer is an Apple framework class so it's never obfuscated or renamed.
- (BOOL)isInGameCheck {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if ([self viewHasMetalLayer:window]) return YES;
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection error: %@", e);
    }
    return NO;
}

- (BOOL)viewHasMetalLayer:(UIView *)view {
    // Check the view's own layer
    if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;

    // Check sublayers
    for (CALayer *sub in view.layer.sublayers ?: @[]) {
        if ([sub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        // One level deeper on layers
        for (CALayer *subsub in sub.sublayers ?: @[]) {
            if ([subsub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        }
    }

    // Recurse into subviews
    for (UIView *sub in view.subviews) {
        if ([self viewHasMetalLayer:sub]) return YES;
    }

    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = (UIWindowScene *)
            [UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) {
            NSLog(@"[XZX] No window scene");
            return;
        }

        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) {
            NSLog(@"[XZX] ERROR: Could not resolve MainViewController");
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
