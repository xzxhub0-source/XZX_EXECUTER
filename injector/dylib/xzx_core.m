#import "xzx_core.h"
#import "xzx_hooks.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>

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
        [self createInvisibleOverlay];
        [self startGameMonitoring];
    });
}

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
    self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = vc;
    
    // Make window completely invisible (zero size, zero alpha, hidden)
    self.overlayWindow.frame = CGRectZero;
    self.overlayWindow.alpha = 0.0;
    self.overlayWindow.hidden = YES;
    
    NSLog(@"[XZX] Invisible overlay created (frame zero, alpha 0, hidden)");
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;
    
    dispatch_async(monitorQueue, ^{
        // No initial delay needed – placeId will be 0 until game starts
        NSLog(@"[XZX] Monitoring for placeId > 0...");
        
        while (YES) {
            @autoreleasepool {
                BOOL inGameNow = isPlayerInGame();  // from xzx_hooks.m
                
                if (inGameNow) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                    if (self.positiveCount == 1) {
                        NSLog(@"[XZX] placeId > 0 detected");
                    }
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }
                
                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] ✅ In game - showing overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                }
                else if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] ❌ Left game - hiding overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (void)showOverlay {
    if (!self.overlayWindow) return;
    if (self.inGame == NO) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Resize to full screen and make visible
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.overlayWindow.frame = screenBounds;
        self.overlayWindow.alpha = 1.0;
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        
        // Notify Swift view controller to become visible
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXMakeVisible" object:nil];
        
        NSLog(@"[XZX] Overlay shown (full screen)");
    });
}

- (void)hideOverlay {
    if (!self.overlayWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Shrink back to zero and hide
        self.overlayWindow.frame = CGRectZero;
        self.overlayWindow.alpha = 0.0;
        self.overlayWindow.hidden = YES;
        
        // Notify Swift view controller to become invisible
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXMakeInvisible" object:nil];
        
        // Return focus to Roblox window
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *win in ws.windows) {
                    if (win != self.overlayWindow) {
                        [win makeKeyWindow];
                        break;
                    }
                }
            }
        }
        NSLog(@"[XZX] Overlay hidden (frame zero)");
    });
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden && _overlayWindow.alpha > 0; }
- (BOOL)isInGame { return _inGame; }

@end
