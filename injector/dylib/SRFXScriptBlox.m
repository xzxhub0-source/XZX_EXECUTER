#import "SRFXScriptBlox.h"

static NSString * const kBaseURL = @"https://scriptblox.com/api";

@implementation SRFXScriptBlox

+ (void)fetchTrending:(void(^)(NSArray *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/scripts?sort=trending&limit=50", kBaseURL];
    NSURL *url = [NSURL URLWithString:urlStr];

    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!data) { completion(@[]); return; }
        NSError *jsonErr;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (![json isKindOfClass:[NSDictionary class]]) { completion(@[]); return; }

        NSArray *scripts = json[@"scripts"];
        NSMutableArray *result = [NSMutableArray array];
        for (NSDictionary *s in scripts) {
            [result addObject:@{
                @"title": s[@"title"] ?: @"",
                @"author": s[@"author"] ?: @"",
                @"game": s[@"game"] ?: @"",
                @"slug": s[@"slug"] ?: @"",
                @"verified": s[@"verified"] ?: @NO
            }];
        }
        completion(result);
    }] resume];
}

+ (void)fetchScript:(NSString *)slug completion:(void(^)(NSString *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/scripts/%@", kBaseURL, slug];
    NSURL *url = [NSURL URLWithString:urlStr];

    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!data) { completion(@""); return; }
        NSError *jsonErr;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if ([json isKindOfClass:[NSDictionary class]]) {
            NSString *code = json[@"script"];
            if (code) { completion(code); return; }
        }
        completion(@"");
    }] resume];
}

+ (void)search:(NSString *)query completion:(void(^)(NSArray *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/scripts?search=%@&limit=30",
                        kBaseURL, [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    NSURL *url = [NSURL URLWithString:urlStr];
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!data) { completion(@[]); return; }
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([json isKindOfClass:[NSDictionary class]]) {
            NSArray *scripts = json[@"scripts"];
            NSMutableArray *result = [NSMutableArray array];
            for (NSDictionary *s in scripts) {
                [result addObject:@{
                    @"title": s[@"title"] ?: @"",
                    @"slug": s[@"slug"] ?: @""
                }];
            }
            completion(result);
        } else {
            completion(@[]);
        }
    }] resume];
}

@end
