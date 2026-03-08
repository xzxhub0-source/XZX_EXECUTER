#import "xzx_scriptblox.h"

static XZXScriptBlox *sharedScriptBloxInstance = nil;

@implementation XZXScriptBlox

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedScriptBloxInstance = [[self alloc] init];
    });
    return sharedScriptBloxInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.apiBaseUrl = @"https://scriptblox-api-proxy.vercel.app";
    }
    return self;
}

- (void)searchScripts:(NSString *)query completion:(void (^)(NSArray *, NSError *))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/search?q=%@&page=1&mode=free", 
                          self.apiBaseUrl, 
                          [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            completion(nil, jsonError);
            return;
        }
        
        NSArray *scripts = json[@"result"][@"scripts"];
        completion(scripts, nil);
    }];
    
    [task resume];
}

- (void)getScriptDetails:(NSString *)scriptId completion:(void (^)(NSDictionary *, NSError *))completion {
    NSString *urlString = [NSString stringWithFormat:@"https://scriptblox.com/api/script/%@", scriptId];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            completion(nil, jsonError);
            return;
        }
        
        completion(json[@"script"], nil);
    }];
    
    [task resume];
}

- (void)getTrendingScripts:(void (^)(NSArray *, NSError *))completion {
    [self searchScripts:@"" completion:completion];
}

@end
