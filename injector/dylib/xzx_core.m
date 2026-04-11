#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static const NSInteger kDebounceShow = 2;   // 2 consecutive positives to show
static const NSInteger kDebounceHide = 15;  // 15 consecutive negatives to hide (survives loading→game transition)

@interface XZXCore ()
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@property (nonatomic, strong) UIWindow *overlayWindow;
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
        [self startGameMonitoring];
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait 8 seconds on startup — gives Roblox time to fully past its
        // loading screen before we start detection, so we never trigger
        // show during the loading phase.
        [NSThread sleepForTimeInterval:8.0];
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
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                // Show after kDebounceShow consecutive positives
                if (!self.inGame && self.positiveCount >= kDebounceShow) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected - showing UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                }
                // Hide only after kDebounceHide consecutive negatives
                // 15 seconds covers the full loading→game world transition
                else if (self.inGame && self.negativeCount >= kDebounceHide) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Left game - hiding UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

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

        if (hasMetalLayer && statusBarHidden && buttonCount < 6) {
            return YES;
        }
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
        if (count > 10) return count;
        for (UIView *sub in view.subviews) {
            count += [self countButtonsInView:sub];
            if (count > 10) return count;
        }
    } @catch (NSException *e) {}
    return count;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) { NSLog(@"[XZX] No scene"); return; }

        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) { NSLog(@"[XZX] VC not found"); return; }

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
