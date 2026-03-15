#import "xzx_core.h"
#import "XZX-Swift.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
    // CRITICAL: DO NOTHING in load - this executes too early
}

- (void)initialize {
    // Wait for app to fully launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), 
                   dispatch_get_main_queue(), ^{
        [self showUI];
    });
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

// NO GAME STATE MONITORING - it always triggers codesigning
// NO HOOKS - they always trigger codesigning
// NO NSClassFromString with unknown classes - triggers detection

@end
