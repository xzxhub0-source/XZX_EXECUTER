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
        NSLog(@"[XZX] Core initialized, waiting for game join...");
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;
    
    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:3.0];
        
        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self detectGame];
                
                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            [self showOverlay];
                            NSLog(@"[XZX] Game detected - UI shown");
                        });
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
        Class dataModelClass = NSClassFromString(@"RobloxDataModel");
        if (dataModelClass) {
            SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
            if ([dataModelClass respondsToSelector:sharedSel]) {
                id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
                if (dataModel) {
                    SEL placeIdSel = NSSelectorFromString(@"placeId");
                    if ([dataModel respondsToSelector:placeIdSel]) {
                        id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
                        if (placeId != nil && [placeId intValue] != 0) {
                            NSLog(@"[XZX] In game - placeId: %@", placeId);
                            return YES;
                        }
                    }
                    
                    SEL gameLoadedSel = NSSelectorFromString(@"gameLoaded");
                    if ([dataModel respondsToSelector:gameLoadedSel]) {
                        BOOL gameLoaded = ((BOOL(*)(id, SEL))objc_msgSend)(dataModel, gameLoadedSel);
                        if (gameLoaded) {
                            NSLog(@"[XZX] In game - gameLoaded: YES");
                            return YES;
                        }
                    }
                }
            }
        }
        
        UIWindow *keyWindow = nil;
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (scene) {
            keyWindow = scene.keyWindow;
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow && keyWindow.rootViewController) {
            UIViewController *topVC = keyWindow.rootViewController;
            while (topVC.presentedViewController) {
                topVC = topVC.presentedViewController;
            }
            
            NSString *className = NSStringFromClass([topVC class]);
            
            if ([className containsString:@"Gameplay"] || 
                [className containsString:@"InGame"] ||
                [className containsString:@"PlayView"]) {
                return YES;
            }
        }
        
    } @catch (NSException *e) {
        // Silently fail
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
