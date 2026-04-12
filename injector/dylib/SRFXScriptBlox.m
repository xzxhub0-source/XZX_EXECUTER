#import "SRFXScriptBlox.h"
@implementation SRFXScriptBlox
+ (void)fetchTrending:(void(^)(NSArray *))completion {
    NSURL *url = [NSURL URLWithString:@"https://scriptblox.com/api/scripts?sort=trending&limit=50"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        if (data) {
            NSError *err;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSArray *scripts = json[@"scripts"];
                NSMutableArray *res = [NSMutableArray array];
                for (NSDictionary *s in scripts) {
                    [res addObject:@{
                        @"title": s[@"title"] ?: @"",
                        @"author": s[@"author"] ?: @"",
                        @"game": s[@"game"] ?: @"",
                        @"slug": s[@"slug"] ?: @""
                    }];
                }
                completion(res);
                return;
            }
        }
        completion(@[]);
    }];
    [task resume];
}
+ (void)fetchScript:(NSString *)slug completion:(void(^)(NSString *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"https://scriptblox.com/api/scripts/%@", slug];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        if (data) {
            NSError *err;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSString *code = json[@"script"];
                if (code) {
                    completion(code);
                    return;
                }
            }
        }
        completion(@"");
    }];
    [task resume];
}
@end
