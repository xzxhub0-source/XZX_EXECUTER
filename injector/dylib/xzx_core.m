#import "xzx_core.h"
#import "XZX-Swift.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>

static XZXCore *sharedCoreInstance = nil;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCoreInstance = [[XZXCore alloc] init];
    });
    return sharedCoreInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInGame = NO;
    }
    return self;
}

+ (void)load {
    // DO NOTHING in load – it's too early and can trigger codesigning
}

- (void)initialize {
    // Delay all initialization to avoid early execution
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self delayedInit];
    });
}

- (void)delayedInit {
    // Initialize Lua safely
    InitLua();
    
    // Start polling for game state (using only safe KVC, no swizzling)
    [self startSafePolling];
}

- (void)startSafePolling {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            @autoreleasepool {
                BOOL inGame = [self safeCheckInGame];
                if (inGame && !self.isInGame) {
                    self.isInGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showUI];
                    });
                } else if (!inGame && self.isInGame) {
                    self.isInGame = NO;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideUI];
                    });
                }
            }
            [NSThread sleepForTimeInterval:2.0]; // Poll less frequently
        }
    });
}

- (BOOL)safeCheckInGame {
    @try {
        // Use only KVC – no performSelector with unknown selectors
        Class dataModelClass = NSClassFromString(@"RobloxDataModel");
        if (!dataModelClass) return NO;
        
        id dataModel = [dataModelClass valueForKey:@"sharedDataModel"];
        if (!dataModel) return NO;
        
        id placeId = [dataModel valueForKey:@"placeId"];
        return (placeId != nil);
    } @catch (NSException *e) {
        return NO;
    }
}

- (void)showUI {
    if (!self.editorWindow) {
        MainViewController *vc = [[MainViewController alloc] init];
        self.editorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.editorWindow.windowLevel = UIWindowLevelAlert + 1;
        self.editorWindow.rootViewController = vc;
        self.editorWindow.backgroundColor = [UIColor clearColor];
    }
    self.editorWindow.hidden = NO;
    [self.editorWindow makeKeyAndVisible];
}

- (void)hideUI {
    self.editorWindow.hidden = YES;
}

@end
