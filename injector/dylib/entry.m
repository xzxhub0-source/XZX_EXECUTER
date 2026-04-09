#import <UIKit/UIKit.h>
#import "xzx_core.h"

__attribute__((constructor))
static void entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide every window upfront. The monitor loop is the only thing
        // that should ever call showOverlay, and only after placeId > 0.
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            win.hidden = YES;
        }
        [[XZXCore shared] initialize];
    });
}
