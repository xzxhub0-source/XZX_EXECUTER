// xzx_core.m - FINAL SAFE VERSION
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

// NO +load method. It's too early and can be detected.

- (void)showUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.editorWindow) {
            MainViewController *vc = [[MainViewController alloc] init];
            self.editorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.editorWindow.windowLevel = UIWindowLevelAlert + 1;
            self.editorWindow.rootViewController = vc;
            self.editorWindow.backgroundColor = [UIColor clearColor];
        }
        self.editorWindow.hidden = NO;
    });
}

// This method is called by your Swift UI when the user taps "Execute"
- (void)executeScript:(NSString *)script {
    // Call your Lua engine here (from LuaExecutor.mm)
    // This runs in your own Lua state, not Roblox's.
    ExecuteScript(script);
}

@end
