#import <UIKit/UIKit.h>
#import "xzx_core.h"
__attribute__((constructor))
static void xzx_entry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[XZXCore shared] xzxStart]; });
}
