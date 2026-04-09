#import <UIKit/UIKit.h>
#import "xzx_core.h"

__attribute__((constructor))
static void entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            win.hidden = YES;
        }
        [[XZXCore shared] initialize];
    });
}
