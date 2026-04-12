#import <Foundation/Foundation.h>

@interface SRFXMemory : NSObject
+ (void)obfuscate;
+ (void)encryptPage:(void *)page size:(size_t)size;
+ (void)decryptPage:(void *)page size:(size_t)size;
@end
