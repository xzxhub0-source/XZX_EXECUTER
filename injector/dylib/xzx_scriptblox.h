#ifndef XZX_SCRIPTBLOX_H
#define XZX_SCRIPTBLOX_H

#import <Foundation/Foundation.h>

@interface XZXScriptBlox : NSObject
+ (instancetype)shared;
- (void)searchScripts:(NSString *)query completion:(void (^)(NSArray *scripts, NSError *error))completion;
- (void)getScriptDetails:(NSString *)scriptId completion:(void (^)(NSDictionary *details, NSError *error))completion;
- (void)getTrendingScripts:(void (^)(NSArray *scripts, NSError *error))completion;

@property (nonatomic, strong) NSString *apiBaseUrl;
@end

#endif
