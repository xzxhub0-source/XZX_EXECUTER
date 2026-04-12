#import "srfx_security.h"
@implementation SRFXSecurity
+ (instancetype)shared { static id i; static dispatch_once_t t; dispatch_once(&t,^{ i=[[self alloc] init];}); return i; }
@end
