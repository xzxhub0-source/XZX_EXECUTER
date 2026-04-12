#import <Foundation/Foundation.h>
@interface SRFXScriptBlox : NSObject
+ (void)fetchTrending:(void(^)(NSArray *))completion;
+ (void)fetchScript:(NSString *)slug completion:(void(^)(NSString *))completion;
@end
