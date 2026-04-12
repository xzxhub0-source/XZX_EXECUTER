#import "SRFXSecurity.h"
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
}

+ (BOOL)isDebuggerAttached {
    return NO;
}

@end
