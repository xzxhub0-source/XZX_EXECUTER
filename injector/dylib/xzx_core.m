#import "xzx_core.h"
#import "xzx_hooks.h"
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
    InitLua();
    
    // Ensure overlay is hidden before monitoring starts
    if (_overlayWindow) _overlayWindow.hidden = YES;
    
    NSLog(@"[XZX] Initialized, watching for game...");
    [self startGameMonitoring];
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;
    
    dispatch_async(monitorQueue, ^{
        // Wait 8 seconds for Roblox to fully bootstrap (login/menu)
        [NSThread sleepForTimeInterval:8.0];
        
        while (YES) {
            @autoreleasepool {
                BOOL raw = [self isInGameCheck];
                
                if (raw) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }
                
                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected (placeId > 0)");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                }
                
                if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Left game (placeId = 0)");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)isInGameCheck {
    @try {
        // Try all known Roblox DataModel class names
        NSArray *classNames = @[
            @"RobloxDataModel",
            @"RBXDataModel",
            @"DataModel",
            @"RBXGame",
            @"RobloxGame"
        ];
        
        Class dmClass = nil;
        for (NSString *name in classNames) {
            dmClass = NSClassFromString(name);
            if (dmClass) break;
        }
        
        if (dmClass) {
            return (BOOL)isPlayerInGame();
        }
        
        return NO;
    } @catch (NSException *e) {
        NSLog(@"[XZX] isInGameCheck error: %@", e);
    }
    return NO;
}

- (void)showOverlay {
    if (!self.inGame) {
        NSLog(@"[XZX] showOverlay called while not in game — ignored");
        return;
    }
    if (_overlayWindow && !_overlayWindow.hidden) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) {
            NSLog(@"[XZX] No window scene found");
            return;
        }
        
        UIViewController *vc = nil;
        vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
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
            self.overlayWindow.hidden = YES;
        }
        
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = YES;
            // Return key focus to Roblox's window
            UIWindow *robloxWindow = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    for (UIWindow *win in ws.windows) {
                        if (win != self.overlayWindow) {
                            robloxWindow = win;
                            break;
                        }
                    }
                }
            }
            [robloxWindow makeKeyWindow];
        }
        NSLog(@"[XZX] Overlay hidden");
    });
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
