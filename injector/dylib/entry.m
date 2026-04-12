#import <UIKit/UIKit.h>
#import "SRFXCore.h"

__attribute__((constructor))
static void srfx_entry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [[SRFXCore shared] start];
    });
}
