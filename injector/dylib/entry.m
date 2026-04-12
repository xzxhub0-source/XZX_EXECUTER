#import <UIKit/UIKit.h>
#import "SRFXCore.h"
__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[SRFXCore shared] start];
    });
}
