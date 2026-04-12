#import <UIKit/UIKit.h>
#import "SRFXCore.h"

static uint32_t random_delay(void) {
    return (arc4random_uniform(4) + 3) * NSEC_PER_SEC;
}

__attribute__((constructor))
static void initialize(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, random_delay()),
                   dispatch_get_main_queue(), ^{
        if (@available(iOS 15.0, *)) {
            [[SRFXCore shared] start];
        }
    });
}
