#import "SRFXScriptBlox.h"

@implementation SRFXScriptBlox

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)url {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                timeoutInterval:12.0];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
       forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    return req;
}

+ (NSMutableArray *)parseScripts:(NSArray *)scripts {
    NSMutableArray *res = [NSMutableArray array];
    for (id item in scripts) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *s = (NSDictionary *)item;
        id gameObj = s[@"game"];
        NSString *gameName = @"Universal";
        NSString *imageUrl = @"";
        if ([gameObj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *game = (NSDictionary *)gameObj;
            gameName = game[@"name"] ?: @"Universal";
            imageUrl = game[@"imageUrl"] ?: @"";
        }
        id viewsObj = s[@"views"];
        NSString *views = viewsObj ? [NSString stringWithFormat:@"%@", viewsObj] : @"0";
        NSNumber *universal = s[@"isUniversal"] ?: @NO;
        if ([universal boolValue]) gameName = @"Universal";
        [res addObject:@{
            @"title":     s[@"title"]  ?: @"Untitled",
            @"game":      gameName,
            @"slug":      s[@"slug"]   ?: @"",
            @"views":     views,
            @"imageUrl":  imageUrl,
            @"isPatched": s[@"isPatched"] ?: @NO,
        }];
    }
    return res;
}

+ (void)fetchTrending:(void(^)(NSArray *))completion {
    NSURL *url = [NSURL URLWithString:
        @"https://scriptblox.com/api/script/fetch?page=1&max=20&mode=free"];
    NSMutableURLRequest *req = [self requestWithURL:url];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d && !e) {
            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                id resultObj = ((NSDictionary *)json)[@"result"];
                if ([resultObj isKindOfClass:[NSDictionary class]]) {
                    NSArray *scripts = ((NSDictionary *)resultObj)[@"scripts"];
                    if ([scripts isKindOfClass:[NSArray class]]) {
                        completion([self parseScripts:scripts]);
                        return;
                    }
                }
            }
        }
        completion(@[]);
    }] resume];
}

+ (void)fetchScript:(NSString *)slug completion:(void(^)(NSString *))completion {
    if (!slug.length) { completion(@""); return; }
    NSString *urlStr = [NSString stringWithFormat:
        @"https://scriptblox.com/api/script/%@", slug];
    NSMutableURLRequest *req = [self requestWithURL:[NSURL URLWithString:urlStr]];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d && !e) {
            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSDictionary *result = ((NSDictionary *)json)[@"result"];
                NSString *code = nil;
                if ([result isKindOfClass:[NSDictionary class]])
                    code = result[@"script"] ?: result[@"rawScript"] ?: result[@"content"];
                if (!code)
                    code = ((NSDictionary *)json)[@"script"] ?: ((NSDictionary *)json)[@"rawScript"];
                if (code.length) { completion(code); return; }
            }
        }
        completion(@"");
    }] resume];
}

+ (void)search:(NSString *)query completion:(void(^)(NSArray *))completion {
    NSString *enc = [query stringByAddingPercentEncodingWithAllowedCharacters:
        [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:
        @"https://scriptblox.com/api/script/search?q=%@&max=20&mode=free", enc];
    NSMutableURLRequest *req = [self requestWithURL:[NSURL URLWithString:urlStr]];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d && !e) {
            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) {
                id resultObj = ((NSDictionary *)json)[@"result"];
                if ([resultObj isKindOfClass:[NSDictionary class]]) {
                    NSArray *scripts = ((NSDictionary *)resultObj)[@"scripts"];
                    if ([scripts isKindOfClass:[NSArray class]]) {
                        completion([self parseScripts:scripts]);
                        return;
                    }
                }
            }
        }
        completion(@[]);
    }] resume];
}

@end
