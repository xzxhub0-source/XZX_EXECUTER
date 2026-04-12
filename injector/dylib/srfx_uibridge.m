#import "srfx_uibridge.h"
@implementation SRFXUIBridge
+ (instancetype)shared { static id i; static dispatch_once_t t; dispatch_once(&t,^{ i=[[self alloc] init];}); return i; }
@end
