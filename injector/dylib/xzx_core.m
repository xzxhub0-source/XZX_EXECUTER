#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "xzx_obfuscator.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;

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
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Initialize Lua
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        // FORCE UI AFTER 3 SECONDS – FOR TESTING
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSLog(@"[XZX] Forcing UI to appear (test mode)");
            [self showOverlay];
        });
    });
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
        
        // Try multiple class name possibilities
        UIViewController *vc = nil;
        vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) {
            vc = [[NSClassFromString(@"XZX.XZXMainViewController") alloc] init];
        }
        if (!vc) {
            vc = [[NSClassFromString(@"XZX_MainViewController") alloc] init];
        }
        if (!vc) {
            NSLog(@"[XZX] Failed to create MainViewController – class not found");
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
