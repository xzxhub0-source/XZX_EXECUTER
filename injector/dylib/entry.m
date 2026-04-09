#import <UIKit/UIKit.h>
#import "xzx_core.h"

__attribute__((constructor))
static void entry() {
    // Small delay ensures any storyboard-created windows are present
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // Force-hide EVERY window – including storyboard's main window
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            win.hidden = YES;
        }
        // Also hide any overlay window that might have been created prematurely
        if ([XZXCore shared].overlayWindow) {
            [XZXCore shared].overlayWindow.hidden = YES;
        }
        [[XZXCore shared] initialize];
    });
}
