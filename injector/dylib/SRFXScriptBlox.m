#import "SRFXScriptBlox.h"

@implementation SRFXScriptBlox

+ (void)fetchTrending:(void(^)(NSArray *))completion {
    NSURL *url = [NSURL URLWithString:@"https://scriptblox.com/api/scripts?sort=trending&limit=50"];
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d) {
            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
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
    }] resume];
}

+ (void)fetchScript:(NSString *)slug completion:(void(^)(NSString *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"https://scriptblox.com/api/scripts/%@", slug];
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d) {
            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSString *code = json[@"script"];
                if (code) { completion(code); return; }
            }
        }
        completion(@"");
    }] resume];
}

+ (void)search:(NSString *)query completion:(void(^)(NSArray *))completion {
    NSString *enc = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:@"https://scriptblox.com/api/scripts?search=%@&limit=30", enc];
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d) {
            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSArray *scripts = json[@"scripts"];
                NSMutableArray *res = [NSMutableArray array];
                for (NSDictionary *s in scripts) {
                    [res addObject:@{@"title": s[@"title"] ?: @"", @"slug": s[@"slug"] ?: @""}];
                }
                completion(res);
                return;
            }
        }
        completion(@[]);
    }] resume];
}

@end
