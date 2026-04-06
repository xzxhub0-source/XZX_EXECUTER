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
        [self startGameMonitoring];
        NSLog(@"[XZX] Core initialized, waiting for game engine...");
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait for Roblox to fully start
        [NSThread sleepForTimeInterval:3.0];
        
        // Track state changes
        BOOL wasInGame = NO;
        
        while (YES) {
            @autoreleasepool {
                BOOL isGameRunning = [self isGameEngineActive];
                
                // State change: entered game
                if (isGameRunning && !wasInGame) {
                    NSLog(@"[XZX] Game engine active - UI will appear");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Small delay to ensure render target is ready
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            [self showOverlay];
                            NSLog(@"[XZX] UI rendered");
                        });
                    });
                }
                // State change: left game
                else if (!isGameRunning && wasInGame) {
                    NSLog(@"[XZX] Game engine stopped - hiding UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
                
                wasInGame = isGameRunning;
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)isGameEngineActive {
    @try {
        // Method 1: Check for PlayerList in CoreGui (most reliable)
        Class coreGuiClass = NSClassFromString(@"CoreGui");
        if (coreGuiClass) {
            SEL getCoreGuiSel = NSSelectorFromString(@"coreGui");
            if ([coreGuiClass respondsToSelector:getCoreGuiSel]) {
                id coreGui = ((id(*)(id, SEL))objc_msgSend)((id)coreGuiClass, getCoreGuiSel);
                if (coreGui) {
                    SEL findFirstChildSel = NSSelectorFromString(@"FindFirstChild:");
                    if ([coreGui respondsToSelector:findFirstChildSel]) {
                        id playerList = ((id(*)(id, SEL, id))objc_msgSend)(coreGui, findFirstChildSel, @"PlayerList");
                        if (playerList) {
                            NSLog(@"[XZX] PlayerList found – game engine active");
                            return YES;
                        }
                    }
                }
            }
        }
        
        // Method 2: Check placeId
        Class dataModelClass = NSClassFromString(@"RobloxDataModel");
        if (dataModelClass) {
            SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
            if ([dataModelClass respondsToSelector:sharedSel]) {
                id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
                if (dataModel) {
                    SEL placeIdSel = NSSelectorFromString(@"placeId");
                    if ([dataModel respondsToSelector:placeIdSel]) {
                        id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
                        if (placeId && [placeId intValue] != 0) {
                            NSLog(@"[XZX] placeId = %@ (non-zero)", placeId);
                            return YES;
                        }
                    }
                }
            }
        }
        
        // Method 3: Check for game view controller
        UIWindow *keyWindow = nil;
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (scene) keyWindow = scene.keyWindow;
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
        
        if (keyWindow && keyWindow.rootViewController) {
            UIViewController *topVC = keyWindow.rootViewController;
            while (topVC.presentedViewController) topVC = topVC.presentedViewController;
            NSString *className = NSStringFromClass([topVC class]);
            if ([className containsString:@"Gameplay"] || 
                [className containsString:@"InGame"] ||
                [className containsString:@"PlayView"]) {
                NSLog(@"[XZX] Game view controller detected");
                return YES;
            }
        }
        
    } @catch (NSException *e) {
        // Ignore
    }
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

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
        NSLog(@"[XZX] Overlay window attached to renderer");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = YES;
            NSLog(@"[XZX] Overlay detached");
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
