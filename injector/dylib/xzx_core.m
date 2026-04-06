#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;

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
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        // Start monitoring for game join
        [self startGameMonitoring];
        
        // Don't show UI immediately - wait for game join
        // The UI will be shown when startGameMonitoring detects a game
        NSLog(@"[XZX] Core initialized, waiting for game join...");
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;
    
    dispatch_async(monitorQueue, ^{
        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self detectGame];
                
                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                        NSLog(@"[XZX] Game detected - UI shown");
                    });
                } else if (!currentlyInGame && self.inGame) {
                    self.inGame = NO;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                        NSLog(@"[XZX] Left game - UI hidden");
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)detectGame {
    @try {
        // Method 1: Check for Roblox view controller in the window hierarchy
        UIWindow *keyWindow = nil;
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (scene) {
            keyWindow = scene.keyWindow;
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow && keyWindow.rootViewController) {
            NSString *className = NSStringFromClass([keyWindow.rootViewController class]);
            if ([className containsString:@"Roblox"] || 
                [className containsString:@"Game"] ||
                [className containsString:@"Play"]) {
                return YES;
            }
        }
        
        // Method 2: Check for Roblox windows
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!window.hidden) {
                NSString *description = [window description];
                if ([description containsString:@"Roblox"] || 
                    [description containsString:@"GameView"] ||
                    [description containsString:@"RBX"]) {
                    return YES;
                }
            }
        }
        
        // Method 3: Try to get the DataModel via known selectors
        Class dataModelClass = NSClassFromString(@"RobloxDataModel");
        if (dataModelClass) {
            SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
            if ([dataModelClass respondsToSelector:sharedSel]) {
                id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
                if (dataModel) {
                    SEL gameLoadedSel = NSSelectorFromString(@"gameLoaded");
                    if ([dataModel respondsToSelector:gameLoadedSel]) {
                        BOOL gameLoaded = ((BOOL(*)(id, SEL))objc_msgSend)(dataModel, gameLoadedSel);
                        if (gameLoaded) return YES;
                    }
                    
                    SEL placeIdSel = NSSelectorFromString(@"placeId");
                    if ([dataModel respondsToSelector:placeIdSel]) {
                        id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
                        if (placeId != nil) return YES;
                    }
                }
            }
        }
        
    } @catch (NSException *e) {
        // Silently fail - detection will retry
    }
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication] == nil) return;
        
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) return;
        
        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) {
            vc = [[NSClassFromString(@"XZX.XZXMainViewController") alloc] init];
        }
        if (!vc) return;
        
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
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
