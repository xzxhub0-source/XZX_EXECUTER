#import "xzx_core.h"
#import "XZX-Swift.h"
#import "xzx_hooks.h"
#import "xzx_antidetection.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>

static XZXCore *sharedCoreInstance = nil;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCoreInstance = [[self alloc] init];
    });
    return sharedCoreInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInGame = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[XZXCore shared] initialize];
    });
}

- (void)initialize {
    [[XZXAntiDetection shared] initializeProtection];
    
    // Start polling instead of hooking
    [self startGameStatePolling];
    
    // Initialize Lua safely
    InitLua();
}

- (void)applicationDidBecomeActive {
    // Refresh state when app becomes active
}

- (void)startGameStatePolling {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self checkIfInGameSafely];
                if (currentlyInGame && !self.isInGame) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self onGameJoined];
                    });
                } else if (!currentlyInGame && self.isInGame) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self onGameLeft];
                    });
                }
                self.isInGame = currentlyInGame;
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)checkIfInGameSafely {
    @try {
        Class dataModelClass = NSClassFromString(@"RobloxDataModel");
        if (!dataModelClass) return NO;
        
        id dataModel = [dataModelClass performSelector:NSSelectorFromString(@"sharedDataModel")];
        if (!dataModel) return NO;
        
        id placeId = [dataModel performSelector:NSSelectorFromString(@"placeId")];
        return (placeId != nil);
    } @catch (NSException *exception) {
        return NO;
    }
}

- (BOOL)checkIfInGame {
    return [self checkIfInGameSafely];
}

- (void)onGameJoined {
    self.isInGame = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.editorWindow) {
            MainViewController *vc = [[MainViewController alloc] init];
            self.editorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.editorWindow.windowLevel = UIWindowLevelAlert + 1;
            self.editorWindow.rootViewController = vc;
            self.editorWindow.backgroundColor = [UIColor clearColor];
        }
        self.editorWindow.hidden = NO;
        [self.editorWindow makeKeyAndVisible];
    });
}

- (void)onGameLeft {
    self.isInGame = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.editorWindow.hidden = YES;
    });
}

void notify_game_joined(void) {
    [[XZXCore shared] onGameJoined];
}

void notify_game_left(void) {
    [[XZXCore shared] onGameLeft];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
