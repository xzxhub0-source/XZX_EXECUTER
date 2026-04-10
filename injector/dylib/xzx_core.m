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
        _overlayViewController = nil;
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
        
        // Create the UI immediately but make it 0.002 x 0.002 pixels (invisible)
        [self createInvisibleOverlay];
        
        [self startGameMonitoring];
    });
}

// NEW: Create overlay at microscopic size (invisible to human eye)
- (void)createInvisibleOverlay {
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) {
        NSLog(@"[XZX] No scene found for invisible overlay");
        return;
    }
    
    UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
    if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
    if (!vc) {
        NSLog(@"[XZX] ERROR: MainViewController not found");
        return;
    }
    
    self.overlayViewController = vc;
    
    if (!self.overlayWindow) {
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.rootViewController = vc;
        
        // CRITICAL: Set frame to 0.002 x 0.002 pixels (invisible)
        // Also set alpha to 0.01 for extra invisibility
        self.overlayWindow.frame = CGRectMake(0, 0, 0.002, 0.002);
        self.overlayWindow.alpha = 0.01;
        self.overlayWindow.hidden = NO;
        
        NSLog(@"[XZX] Invisible overlay created (0.002 x 0.002 pixels)");
    }
}

// NEW: Resize to normal dimensions when in-game confirmed
- (void)resizeOverlayToNormal {
    if (!self.overlayWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Get screen bounds
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        
        // Animate the resize for smooth transition
        [UIView animateWithDuration:0.3 animations:^{
            self.overlayWindow.frame = screenBounds;
            self.overlayWindow.alpha = 1.0;
        }];
        
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay resized to normal dimensions: %.0f x %.0f", screenBounds.size.width, screenBounds.size.height);
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait 12 seconds — long enough to skip Roblox loading screen
        [NSThread sleepForTimeInterval:12.0];
        NSLog(@"[XZX] Detection active");

        while (YES) {
            @autoreleasepool {
                __block BOOL hasMetalLayer = NO;

                dispatch_sync(dispatch_get_main_queue(), ^{
                    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if ([scene isKindOfClass:[UIWindowScene class]]) {
                            UIWindowScene *ws = (UIWindowScene *)scene;
                            for (UIWindow *window in ws.windows) {
                                if ([self viewHasMetalLayer:window]) {
                                    hasMetalLayer = YES;
                                }
                            }
                        }
                    }
                });

                if (hasMetalLayer) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                    if (self.positiveCount == 1) {
                        NSLog(@"[XZX] CAMetalLayer detected");
                    }
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected - resizing UI to normal size");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self resizeOverlayToNormal];
                    });
                } else if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Left game - shrinking UI back to invisible");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self shrinkOverlayToInvisible];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

// NEW: Shrink back to invisible when leaving game
- (void)shrinkOverlayToInvisible {
    if (!self.overlayWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self.overlayWindow.frame = CGRectMake(0, 0, 0.002, 0.002);
            self.overlayWindow.alpha = 0.01;
        }];
        NSLog(@"[XZX] Overlay shrunk to invisible");
    });
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

- (void)showOverlay {
    // This is now handled by resizeOverlayToNormal
    // Kept for compatibility with existing calls
    [self resizeOverlayToNormal];
}

- (void)hideOverlay {
    [self shrinkOverlayToInvisible];
}

- (BOOL)isOverlayVisible { return _overlayWindow && _overlayWindow.alpha > 0.5 && _overlayWindow.frame.size.width > 100; }
- (BOOL)isInGame { return _inGame; }

@end
