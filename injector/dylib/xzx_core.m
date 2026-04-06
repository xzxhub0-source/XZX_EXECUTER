#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "xzx_obfuscator.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedCore = [[self alloc] init];
    });
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if ([UIApplication sharedApplication] == nil) return;
            InitLua();
            [self startGameMonitoring];
            NSLog(@"[XZX] Core initialized, monitoring for game join");
        });
    });
}

- (void)startGameMonitoring {
    dispatch_async(monitorQueue, ^{
        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self checkIfInGame];
                
                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                        NSLog(@"[XZX] Game detected - showing UI");
                    });
                } else if (!currentlyInGame && self.inGame) {
                    self.inGame = NO;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                        NSLog(@"[XZX] Left game - hiding UI");
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)checkIfInGame {
    @try {
        if ([UIApplication sharedApplication] == nil) return NO;
        
        // Method 1: Check root view controller
        UIWindow *keyWindow = nil;
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (scene) {
            keyWindow = scene.keyWindow;
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow && keyWindow.rootViewController) {
            UIViewController *rootVC = keyWindow.rootViewController;
            NSString *className = NSStringFromClass([rootVC class]);
            
            if ([className containsString:@"Roblox"] || 
                [className containsString:@"Game"] ||
                [className containsString:@"Play"]) {
                return YES;
            }
        }
        
        // Method 2: Check all windows
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.hidden == NO) {
                NSString *description = [window description];
                if ([description containsString:@"Roblox"] || 
                    [description containsString:@"GameView"]) {
                    return YES;
                }
            }
        }
        
        // Method 3: Check subviews of key window
        if (keyWindow) {
            for (UIView *view in [keyWindow subviews]) {
                NSString *viewClass = NSStringFromClass([view class]);
                if ([viewClass containsString:@"Roblox"] || 
                    [viewClass containsString:@"Game"]) {
                    return YES;
                }
            }
        }
        
        // Method 4: Original DataModel method (fallback)
        const char* className = "\x8e\xf5\x9a\xc5\x86\xd1\x8c\xc3\x9c\xd8\x88\xc2\x91\xd7";
        const char* methodName = "\x93\xd1\x80\xce\x9d\xdb\x86\xc2\x9c\xc8\x95\xcf\x83\xcf";
        
        Class cls = xzx_getClass(className);
        if (cls) {
            SEL sel = xzx_getSelector(methodName);
            if ([cls respondsToSelector:sel]) {
                id dm = ((id(*)(id, SEL))objc_msgSend)((id)cls, sel);
                if (dm) {
                    const char* placeSelName = "\x95\xd0\x8f\xc7\x96\xd6";
                    SEL placeSel = xzx_getSelector(placeSelName);
                    if ([dm respondsToSelector:placeSel]) {
                        id pid = ((id(*)(id, SEL))objc_msgSend)(dm, placeSel);
                        if (pid != nil) return YES;
                    }
                }
            }
        }
        
    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection error: %@", e);
    }
    
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) {
        NSLog(@"[XZX] Overlay already visible");
        return;
    }
    
    NSLog(@"[XZX] Attempting to show overlay...");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication] == nil) {
            NSLog(@"[XZX] UIApplication not available");
            return;
        }
        
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) {
            NSLog(@"[XZX] No window scene available, retrying...");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self showOverlay];
            });
            return;
        }
        
        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) {
            NSLog(@"[XZX] Failed to create MainViewController");
            return;
        }
        
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown successfully!");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = YES;
            NSLog(@"[XZX] Overlay hidden");
        }
    });
}

- (BOOL)isOverlayVisible {
    return self.overlayWindow && !self.overlayWindow.hidden;
}

- (BOOL)isInGame {
    return _inGame;
}

@end
