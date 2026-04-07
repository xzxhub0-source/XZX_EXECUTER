#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "xzx_renderer_hook.h"
#import "xzx_task_hook.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static BOOL uiCreated = NO;
static BOOL gameLoadedSignalReceived = NO;
static int asl_file_descriptor = -1;

// Simple signal file path
static NSString *signalFilePath = nil;

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
        
        // Setup signal file in temp directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docPath = [paths firstObject];
        signalFilePath = [docPath stringByAppendingPathComponent:@"xzx_signal.txt"];
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        install_renderer_hook();
        install_task_hook();
        NSLog(@"[XZX] Renderer and task hooks installed");
        
        // Clear any old signal file
        [[NSFileManager defaultManager] removeItemAtPath:signalFilePath error:nil];
        
        [self injectGameLoadedSignal];
        [self startSignalMonitoring];
        [self startGameMonitoring];
        NSLog(@"[XZX] Core initialized, waiting for game join signal...");
    });
}

- (void)injectGameLoadedSignal {
    // This script writes to a file instead of console to avoid ASL deprecation
    NSString *bootstrapScript = @"local Players = game:GetService('Players')\nlocal RunService = game:GetService('RunService')\nlocal HttpService = game:GetService('HttpService')\n\nlocal signalPath = '" [signalFilePath stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"] @"'\n\nlocal function writeSignal()\n    local file = io.open(signalPath, 'w')\n    if file then\n        file:write('LOADED')\n        file:close()\n    end\nend\n\nlocal function checkGameLoaded()\n    local player = Players.LocalPlayer\n    if player and player.Character and player.Character:FindFirstChild('Humanoid') then\n        writeSignal()\n        print('[XZX_GAME_LOADED]')\n        return true\n    end\n    return false\nend\n\nlocal function waitForGame()\n    while not checkGameLoaded() do\n        RunService.Heartbeat:Wait()\n    end\nend\n\ncoroutine.wrap(waitForGame)()\n";
    
    @try {
        Class luaStateClass = NSClassFromString(@"RobloxLuaState");
        if (luaStateClass) {
            SEL getCurrentSel = NSSelectorFromString(@"currentState");
            if ([luaStateClass respondsToSelector:getCurrentSel]) {
                id luaState = ((id(*)(id, SEL))objc_msgSend)((id)luaStateClass, getCurrentSel);
                if (luaState) {
                    SEL loadStringSel = NSSelectorFromString(@"loadString:");
                    SEL pcallSel = NSSelectorFromString(@"pcall:args:results:msgh:");
                    
                    if ([luaState respondsToSelector:loadStringSel] && [luaState respondsToSelector:pcallSel]) {
                        int loadResult = ((int(*)(id, SEL, id))objc_msgSend)(luaState, loadStringSel, bootstrapScript);
                        if (loadResult == 0) {
                            ((void(*)(id, SEL, int, id, int, int))objc_msgSend)(luaState, pcallSel, 0, nil, 0, 0);
                            NSLog(@"[XZX] Game loaded signal script injected");
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] Failed to inject script: %@", e);
    }
}

- (void)startSignalMonitoring {
    dispatch_async(monitorQueue, ^{
        while (YES) {
            @autoreleasepool {
                // Check for signal file
                if ([[NSFileManager defaultManager] fileExistsAtPath:signalFilePath]) {
                    NSString *content = [NSString stringWithContentsOfFile:signalFilePath encoding:NSUTF8StringEncoding error:nil];
                    if ([content containsString:@"LOADED"] && !gameLoadedSignalReceived) {
                        gameLoadedSignalReceived = YES;
                        NSLog(@"[XZX] Game loaded signal detected via file");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self onGameLoaded];
                        });
                    }
                }
                
                // Also check our own logs for the signal (for redundancy)
                [self checkLogForSignal];
            }
            [NSThread sleepForTimeInterval:0.5];
        }
    });
}

- (void)checkLogForSignal {
    // This is a simple fallback - we can't easily read NSLog output,
    // but we can rely on the file signal which works reliably
}

- (void)onGameLoaded {
    if (!uiCreated) {
        [self createOverlay];
    } else {
        [self showOverlay];
    }
    NSLog(@"[XZX] Game loaded - UI shown");
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:3.0];

        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self isGameEngineActive];

                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Re-inject the signal script when entering a game
                        [self injectGameLoadedSignal];
                    });
                } else if (!currentlyInGame && self.inGame) {
                    self.inGame = NO;
                    gameLoadedSignalReceived = NO;
                    // Clear signal file when leaving game
                    [[NSFileManager defaultManager] removeItemAtPath:signalFilePath error:nil];
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
        // Check for PlayerList in CoreGui
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
                            return YES;
                        }
                    }
                }
            }
        }

        // Check placeId
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
                            return YES;
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {}
    return NO;
}

- (void)createOverlay {
    if (uiCreated) return;
    uiCreated = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication] == nil) return;

        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) {
            uiCreated = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self createOverlay];
            });
            return;
        }

        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) {
            vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        }
        if (!vc) {
            vc = [[NSClassFromString(@"MainViewController") alloc] init];
        }
        if (!vc) return;

        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay created");
    });
}

- (void)showOverlay {
    if (!uiCreated) {
        [self createOverlay];
    } else if (self.overlayWindow && self.overlayWindow.hidden) {
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
    }
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow && !self.overlayWindow.hidden) {
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
