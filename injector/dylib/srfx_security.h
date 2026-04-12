#import <Foundation/Foundation.h>

@interface SRFXSecurity : NSObject
+ (NSString *)spoofedHWID;
+ (void)installAntiDebug;
+ (BOOL)isDebuggerAttached;
@end
