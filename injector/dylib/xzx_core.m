#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static const NSInteger kDebounceThreshold = 3;

@interface XZXCore ()
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
        _overlayWindow = nil;
        _isInitialized = NO;
        _inGame = NO;
        _positiveCount = 0;
        _negativeCount = 0;
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
        // Wait for Roblox to load
        [NSThread sleepForTimeInterval:8.0];
        NSLog(@"[XZX] Monitoring for CAMetalLayer...");

        while (YES) {
            @autoreleasepool {
                __block BOOL hasMetal = NO;

                dispatch_sync(dispatch_get_main_queue(), ^{
                    // Scan ALL windows and their view hierarchies
                    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if ([scene isKindOfClass:[UIWindowScene class]]) {
                            UIWindowScene *ws = (UIWindowScene *)scene;
                            for (UIWindow *window in ws.windows) {
                                if ([self scanForMetalLayer:window]) {
                                    hasMetal = YES;
                                    break;
                                }
                            }
                        }
                    }
                });

                if (hasMetal) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                    if (self.positiveCount == 1) {
                        NSLog(@"[XZX] CAMetalLayer detected");
                    }
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                // Show after 3 consistent Metal detections
                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected - showing overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                }
                // Hide after 3 consistent absences
                else if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Game left - hiding overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

// Recursively scan entire view hierarchy for CAMetalLayer
- (BOOL)scanForMetalLayer:(UIView *)view {
    @try {
        // Check the view's main layer
        if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) {
            return YES;
        }
        // Check all sublayers
        for (CALayer *sublayer in view.layer.sublayers) {
            if ([sublayer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) {
                return YES;
            }
        }
        // Recursively check all subviews
        for (UIView *subview in view.subviews) {
            if ([self scanForMetalLayer:subview]) {
                return YES;
            }
        }
    } @catch (NSException *e) {
        // Silently fail
    }
    return NO;
}

// Keep for header compatibility
- (BOOL)viewHasMetalLayer:(UIView *)view { return [self scanForMetalLayer:view]; }
- (BOOL)viewHasWebView:(UIView *)view { return NO; }
- (BOOL)isGameEngineActive { return self.inGame; }

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
        if (!scene) { return; }

        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) { return; }

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
