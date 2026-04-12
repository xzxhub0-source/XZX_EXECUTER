#import <UIKit/UIKit.h>
#import "SRFXCore.h"

__attribute__((constructor))
// FIXED: renamed from "initialize" — that symbol name is intercepted by the
// ObjC runtime on iOS 26 (+initialize is a class-method selector), causing
// the runtime to branch to a null stub → crash at PC=0.
static void srfx_entry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [[SRFXCore shared] start];
    });
}
