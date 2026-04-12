#import "SRFXSecurity.h"
#import <sys/sysctl.h>
#import <CommonCrypto/CommonDigest.h>

@implementation SRFXSecurity

+ (NSString *)spoofedHWID {
    NSMutableString *hwid = [NSMutableString string];
    for (int i = 0; i < 32; i++) {
        uint8_t r = arc4random_uniform(16);
        [hwid appendFormat:@"%X", r];
    }

    const char *input = [hwid UTF8String];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(input, (CC_LONG)strlen(input), digest);

    NSMutableString *output = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02X", digest[i]];
    }
    return output;
}

+ (void)installAntiDebug {
    int name[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    if (sysctl(name, 4, &info, &info_size, NULL, 0) != -1) {
        if ((info.kp_proc.p_flag & P_TRACED) != 0) {
            exit(0);
        }
    }

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                      0, 0,
                                                      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        if ([self isDebuggerAttached]) exit(0);
    });
    dispatch_resume(timer);
}

+ (BOOL)isDebuggerAttached {
    int name[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) return NO;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

@end
