#import "xzx_core.h"
#import "xzx_editor.h"
#import "xzx_hooks.h"
#import "xzx_antidetection.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static XZXCore *sharedCoreInstance = nil;
static int gameCheckCounter = 0;

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
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(applicationDidBecomeActive) 
                                                     name:UIApplicationDidBecomeActiveNotification 
                                                   object:nil];
    }
    return self;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 
                   dispatch_get_main_queue(), ^{
        [[XZXCore shared] initialize];
    });
}

- (void)initialize {
    [[XZXAntiDetection shared] initializeProtection];
    [self startGameStateMonitoring];
    hook_roblox_functions();
}

- (void)applicationDidBecomeActive {
    [self startGameStateMonitoring];
}

- (void)startGameStateMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            BOOL currentlyInGame = [self checkIfInGame];
            
            if (currentlyInGame && !self.isInGame) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGameJoined];
                });
            } else if (!currentlyInGame && self.isInGame) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGameLeft];
                });
            }
            
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)checkIfInGame {
    return isPlayerInGame();
}

- (void)onGameJoined {
    self.isInGame = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.editorWindow) {
            self.editorWindow = [[XZXEditor shared] createEditorWindow];
        }
        self.editorWindow.hidden = NO;
        [[XZXEditor shared] show];
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

// REMOVED: - (void)dealloc method entirely - ARC handles this automatically

@end
