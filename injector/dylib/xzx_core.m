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
        
        @try {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *docPath = [paths firstObject];
            if (docPath) {
                signalFilePath = [docPath stringByAppendingPathComponent:@"xzx_signal.txt"];
            } else {
                signalFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"xzx_signal.txt"];
            }
        } @catch (NSException *e) {
            signalFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"xzx_signal.txt"];
        }
    }
    return self;
}

- (void)writeLog:(NSString *)message level:(NSString *)level {
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docPath = [paths firstObject];
        if (!docPath) return;
        
        NSString *logPath = [docPath stringByAppendingPathComponent:@"xzx_logs.txt"];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        
        NSString *logEntry = [NSString stringWithFormat:@"[%@] [%@] %@\n", timestamp, level, message];
        
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
        if (fileHandle) {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
            [fileHandle closeFile];
        } else {
            [logEntry writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        
        NSLog(@"[XZX] %@", message);
    } @catch (NSException *e) {
        NSLog(@"[XZX] Failed to write log: %@", e);
    }
}

- (void)initialize {
    [self writeLog:@"Core initialization started" level:@"INFO"];
    
    if (_isInitialized) return;
    _isInitialized = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self writeLog:@"Lua initialization starting" level:@"DEBUG"];
            InitLua();
            [self writeLog:@"Lua initialized successfully" level:@"INFO"];
        } @catch (NSException *e) {
            [self writeLog:[NSString stringWithFormat:@"Lua init failed: %@", e] level:@"ERROR"];
        }
        
        @try {
            install_renderer_hook();
            install_task_hook();
            [self writeLog:@"Renderer and task hooks installed" level:@"INFO"];
        } @catch (NSException *e) {
            [self writeLog:[NSString stringWithFormat:@"Hook installation failed: %@", e] level:@"ERROR"];
        }
        
        @try {
            [[NSFileManager defaultManager] removeItemAtPath:signalFilePath error:nil];
        } @catch (NSException *e) {}
        
        [self injectGameLoadedSignal];
        [self startSignalMonitoring];
        [self startGameMonitoring];
        
        [self writeLog:@"Core initialized, waiting for game join signal..." level:@"INFO"];
    });
}

- (void)injectGameLoadedSignal {
    [self writeLog:@"Injecting game loaded signal script" level:@"DEBUG"];
    
    @try {
        NSString *escapedPath = [signalFilePath stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escapedPath = [escapedPath stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        
        NSString *bootstrapScript = [NSString stringWithFormat:
            @"local Players = game:GetService('Players')\n"
            @"local RunService = game:GetService('RunService')\n"
            @"local signalPath = '%@'\n"
            @"local function writeSignal()\n"
            @"    local file = io.open(signalPath, 'w')\n"
            @"    if file then\n"
            @"        file:write('LOADED')\n"
            @"        file:close()\n"
            @"    end\n"
            @"end\n"
            @"local function checkGameLoaded()\n"
            @"    local player = Players.LocalPlayer\n"
            @"    if player and player.Character and player.Character:FindFirstChild('Humanoid') then\n"
            @"        writeSignal()\n"
            @"        return true\n"
            @"    end\n"
            @"    return false\n"
            @"end\n"
            @"local function waitForGame()\n"
            @"    while not checkGameLoaded() do\n"
            @"        RunService.Heartbeat:Wait()\n"
            @"    end\n"
            @"end\n"
            @"coroutine.wrap(waitForGame)()\n", escapedPath];
        
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
                            [self writeLog:@"Game loaded signal script injected successfully" level:@"INFO"];
                        } else {
                            [self writeLog:@"Failed to load signal script" level:@"ERROR"];
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {
        [self writeLog:[NSString stringWithFormat:@"Failed to inject script: %@", e] level:@"ERROR"];
    }
}

- (void)startSignalMonitoring {
    [self writeLog:@"Starting signal monitoring" level:@"DEBUG"];
    
    dispatch_async(monitorQueue, ^{
        while (YES) {
            @autoreleasepool {
                @try {
                    if (!gameLoadedSignalReceived && [[NSFileManager defaultManager] fileExistsAtPath:signalFilePath]) {
                        NSString *content = [NSString stringWithContentsOfFile:signalFilePath encoding:NSUTF8StringEncoding error:nil];
                        if (content && [content containsString:@"LOADED"]) {
                            gameLoadedSignalReceived = YES;
                            [self writeLog:@"Game loaded signal detected via file" level:@"INFO"];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self onGameLoaded];
                            });
                        }
                    }
                } @catch (NSException *e) {
                    // Ignore file read errors
                }
            }
            [NSThread sleepForTimeInterval:0.5];
        }
    });
}

- (void)onGameLoaded {
    [self writeLog:@"Game loaded - UI shown" level:@"INFO"];
    
    @try {
        if (!uiCreated) {
            [self createOverlay];
        } else {
            [self showOverlay];
        }
    } @catch (NSException *e) {
        [self writeLog:[NSString stringWithFormat:@"Failed to show UI: %@", e] level:@"ERROR"];
    }
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;
    
    [self writeLog:@"Starting game monitoring" level:@"DEBUG"];

    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:3.0];

        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = NO;
                @try {
                    currentlyInGame = [self isGameEngineActive];
                } @catch (NSException *e) {
                    [self writeLog:[NSString stringWithFormat:@"Game detection error: %@", e] level:@"ERROR"];
                }

                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    [self writeLog:@"Game engine active - in game" level:@"INFO"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self injectGameLoadedSignal];
                    });
                } else if (!currentlyInGame && self.inGame) {
                    self.inGame = NO;
                    gameLoadedSignalReceived = NO;
                    [self writeLog:@"Left game - UI hidden" level:@"INFO"];
                    @try {
                        [[NSFileManager defaultManager] removeItemAtPath:signalFilePath error:nil];
                    } @catch (NSException *e) {}
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)isGameEngineActive {
    BOOL active = NO;
    
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
                            [self writeLog:@"PlayerList found - game engine active" level:@"DEBUG"];
                            active = YES;
                        }
                    }
                }
            }
        }

        if (!active) {
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
                                [self writeLog:[NSString stringWithFormat:@"placeId = %@", placeId] level:@"DEBUG"];
                                active = YES;
                            }
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {
        [self writeLog:[NSString stringWithFormat:@"isGameEngineActive error: %@", e] level:@"ERROR"];
    }
    
    return active;
}

- (void)createOverlay {
    if (uiCreated) return;
    uiCreated = YES;
    
    [self writeLog:@"Creating overlay UI" level:@"INFO"];

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if ([UIApplication sharedApplication] == nil) {
                [self writeLog:@"UIApplication not available" level:@"ERROR"];
                return;
            }

            UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
            if (!scene) {
                [self writeLog:@"No window scene available, retrying..." level:@"WARNING"];
                uiCreated = NO;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self createOverlay];
                });
                return;
            }

            UIViewController *vc = nil;
            NSArray *classNames = @[@"XZXMainViewController", @"XZX.MainViewController", @"MainViewController"];
            for (NSString *className in classNames) {
                vc = [[NSClassFromString(className) alloc] init];
                if (vc) break;
            }
            if (!vc) {
                [self writeLog:@"Could not create MainViewController - class not found" level:@"ERROR"];
                return;
            }

            self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
            self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
            self.overlayWindow.rootViewController = vc;
            self.overlayWindow.backgroundColor = [UIColor clearColor];
            self.overlayWindow.hidden = NO;
            [self.overlayWindow makeKeyAndVisible];
            
            [self writeLog:@"Overlay created successfully" level:@"INFO"];
        } @catch (NSException *e) {
            [self writeLog:[NSString stringWithFormat:@"Failed to create overlay: %@", e] level:@"ERROR"];
            uiCreated = NO;
        }
    });
}

- (void)showOverlay {
    if (!uiCreated) {
        [self createOverlay];
    } else if (self.overlayWindow && self.overlayWindow.hidden) {
        @try {
            self.overlayWindow.hidden = NO;
            [self.overlayWindow makeKeyAndVisible];
            [self writeLog:@"Overlay shown" level:@"INFO"];
        } @catch (NSException *e) {
            [self writeLog:[NSString stringWithFormat:@"Failed to show overlay: %@", e] level:@"ERROR"];
        }
    }
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.overlayWindow && !self.overlayWindow.hidden) {
                self.overlayWindow.hidden = YES;
                [self writeLog:@"Overlay hidden" level:@"INFO"];
            }
        } @catch (NSException *e) {
            // Ignore
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
