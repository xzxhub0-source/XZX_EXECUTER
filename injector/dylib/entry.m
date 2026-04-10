#import <UIKit/UIKit.h>
#import "xzx_core.h"

__attribute__((constructor))
static void entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[XZXCore shared] initialize];
    });
}
