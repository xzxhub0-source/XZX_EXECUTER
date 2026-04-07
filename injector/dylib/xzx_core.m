#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "xzx_renderer_hook.h"
#import "xzx_task_hook.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <asl.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static BOOL uiCreated = NO;
static int asl_file_descriptor = -1;

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
        
        install_renderer_hook();
        install_task_hook();
        NSLog(@"[XZX] Renderer and task hooks installed");
        
        // Inject bootstrap script that signals when game is loaded
        [self injectGameLoadedSignal];
        
        // Start monitoring console for game loaded signal
        [self startConsoleMonitoring];
        
        [self startGameMonitoring];
        NSLog(@"[XZX] Core initialized, waiting for game join...");
    });
}

- (void)injectGameLoadedSignal {
    // This script will run inside Roblox's Lua VM and signal when game is loaded
    NSString *bootstrapScript = @[
        "local Players = game:GetService('Players')",
        "local RunService = game:GetService('RunService')",
        "",
        "local function checkGameLoaded()",
        "    local player = Players.LocalPlayer",
        "    if player and player.Character and player.Character:FindFirstChild('Humanoid') then",
        "        print('[XZX_GAME_LOADED]')",
        "        return true",
        "    end",
        "    return false",
        "end",
        "",
        "local function waitForGame()",
        "    while not checkGameLoaded() do",
        "        RunService.Heartbeat:Wait()",
        "    end",
        "end",
        "",
        "coroutine.wrap(waitForGame)()"
    ].componentsJoinedByString:@"\n"];
    
    // Execute the script in Roblox's Lua state
    [self executeRobloxScript:bootstrapScript];
}

- (void)executeRobloxScript:(NSString *)script {
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
                        int loadResult = ((int(*)(id, SEL, id))objc_msgSend)(luaState, loadStringSel, script);
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

- (void)startConsoleMonitoring {
    dispatch_async(monitorQueue, ^{
        // Method 1: Read from asl (Apple System Log) - works on iOS
        aslmsg q = asl_new(ASL_TYPE_QUERY);
        asl_set_query(q, ASL_KEY_MSG, "[XZX_GAME_LOADED]", ASL_QUERY_OP_EQUAL);
        aslresponse r = asl_search(NULL, q);
        
        aslmsg m;
        while ((m = aslresponse_next(r)) != NULL) {
            const char *msg = asl_get(m, ASL_KEY_MSG);
            if (msg && strstr(msg, "[XZX_GAME_LOADED]")) {
                NSLog(@"[XZX] Game loaded signal detected via ASL");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGameLoaded];
                });
                break;
            }
        }
        aslresponse_free(r);
        asl_free(q);
        
        // Method 2: Also monitor via notification (for our own logs)
        [[NSNotificationCenter defaultCenter] addObserverForName:NSNotification.Name(@"XZXGameLoaded") 
                                                          object:nil 
                                                           queue:[NSOperationQueue mainQueue] 
                                                      usingBlock:^(NSNotification *note) {
            [self onGameLoaded];
        }];
        
        // Method 3: Polling fallback - check for console output file
        while (YES) {
            @autoreleasepool {
                [self checkConsoleForSignal];
            }
            [NSThread sleepForTimeInterval:0.5];
        }
    });
}

- (void)checkConsoleForSignal {
    @try {
        // Check system log for our signal
        NSPipe *pipe = [NSPipe pipe];
        NSFileHandle *file = pipe.fileHandleForReading;
        
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/log";
        task.arguments = @[@"show", @"--predicate", @"eventMessage contains 'XZX_GAME_LOADED'", @"--last", @"1s"];
        task.standardOutput = pipe;
        
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [file readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        if ([output containsString:@"XZX_GAME_LOADED"]) {
            NSLog(@"[XZX] Game loaded signal detected via log command");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onGameLoaded];
            });
        }
    } @catch (NSException *e) {
        // Silently fail - fallback to other detection methods
    }
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
                        // Also inject the signal script again to ensure it runs
                        [self injectGameLoadedSignal];
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
