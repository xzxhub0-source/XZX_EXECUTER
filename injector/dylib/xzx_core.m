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
        NSLog(@"[XZX] Core initialized, waiting for game join...");
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait for Roblox to fully start
        [NSThread sleepForTimeInterval:5.0];

        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self isGameEngineActive];

                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Small extra delay for game scene to stabilize
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            if (!uiCreated) {
                                [self createOverlay];
                            } else {
                                [self showOverlay];
                            }
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

- (BOOL)isGameEngineActive {
    @try {
        // Most reliable: Check for PlayerList in CoreGui (only exists in-game)
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

        // Fallback: check placeId (RobloxDataModel)
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
    } @catch (NSException *e) {
        NSLog(@"[XZX] Game detection error: %@", e);
    }
    return NO;
}

- (void)createOverlay {
    if (uiCreated) return;
    uiCreated = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication] == nil) {
            NSLog(@"[XZX] UIApplication not available");
            return;
        }

        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) {
            NSLog(@"[XZX] No window scene available, retrying...");
            uiCreated = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self createOverlay];
            });
            return;
        }

        // Try multiple class name possibilities (match @objc name)
        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) {
            vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        }
        if (!vc) {
            vc = [[NSClassFromString(@"MainViewController") alloc] init];
        }
        if (!vc) {
            NSLog(@"[XZX] ERROR: MainViewController class not found!");
            return;
        }

        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay created and shown successfully!");
    });
}

- (void)showOverlay {
    if (!uiCreated) {
        [self createOverlay];
    } else if (self.overlayWindow && self.overlayWindow.hidden) {
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown");
    }
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow && !self.overlayWindow.hidden) {
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
