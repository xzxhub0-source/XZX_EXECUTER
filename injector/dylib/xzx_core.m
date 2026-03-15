#import "xzx_core.h"
#import "XZX-Swift.h"
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

// Do absolutely nothing in +load
+ (void)load {
    // Empty
}

// Do absolutely nothing in initialize
- (void)initialize {
    // Empty
}

// Separate method to show UI after a long delay
- (void)showUIAfterDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        MainViewController *vc = [[MainViewController alloc] init];
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.rootViewController = vc;
        window.backgroundColor = [UIColor clearColor];
        window.hidden = NO;
        [window makeKeyAndVisible];
        self.editorWindow = window;
    });
}

- (void)onGameJoined {
    // No-op
}

- (void)onGameLeft {
    // No-op
}

@end
