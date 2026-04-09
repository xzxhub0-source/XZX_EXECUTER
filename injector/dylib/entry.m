#import <UIKit/UIKit.h>
#import "xzx_core.h"

__attribute__((constructor))
static void entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide absolutely every window at startup
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            win.hidden = YES;
        }
        // Ensure no overlay window exists yet
        if ([XZXCore shared].overlayWindow) {
            [XZXCore shared].overlayWindow.hidden = YES;
        }
        [[XZXCore shared] initialize];
    });
}
