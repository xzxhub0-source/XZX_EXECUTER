#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static BOOL uiCreated = NO;

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
        NSLog(@"[XZX] Core initialized, waiting for game...");
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:3.0];
        
        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self isInGameCheck];
                
                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    NSLog(@"[XZX] GAME DETECTED!");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showBlackScreen];
                    });
                } else if (!currentlyInGame && self.inGame) {
                    self.inGame = NO;
                    NSLog(@"[XZX] Left game");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideScreen];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)isInGameCheck {
    @try {
        // Try to get placeId - most reliable method
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
                            NSLog(@"[XZX] placeId = %@", placeId);
                            return YES;
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection error: %@", e);
    }
    return NO;
}

- (void)showBlackScreen {
    if (uiCreated) {
        if (self.overlayWindow && self.overlayWindow.hidden) {
            self.overlayWindow.hidden = NO;
        }
        return;
    }
    
    uiCreated = YES;
    NSLog(@"[XZX] Creating black screen overlay");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) {
            NSLog(@"[XZX] No scene available");
            uiCreated = NO;
            return;
        }
        
        // Simple black view controller
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor blackColor];
        vc.view.alpha = 0.95;
        
        // Add a label so we know it's working
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
        label.text = @"XZX EXECUTOR\nIN-GAME OVERLAY";
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.font = [UIFont boldSystemFontOfSize:20];
        label.center = vc.view.center;
        [vc.view addSubview:label];
        
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        
        NSLog(@"[XZX] Black screen overlay shown!");
    });
}

- (void)hideScreen {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = YES;
            NSLog(@"[XZX] Screen hidden");
        }
    });
}

- (void)showOverlay {
    [self showBlackScreen];
}

- (void)hideOverlay {
    [self hideScreen];
}

- (BOOL)isOverlayVisible {
    return self.overlayWindow && !self.overlayWindow.hidden;
}

- (BOOL)isInGame {
    return _inGame;
}

@end
