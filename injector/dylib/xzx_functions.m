#import "xzx_functions.h"
#import <Foundation/Foundation.h>

static XZXFunctions *sharedFunctionsInstance = nil;

@implementation XZXFunctions

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedFunctionsInstance = [[self alloc] init];
    });
    return sharedFunctionsInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fflags = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)executeLuaScript:(NSString *)script {
    // Placeholder
}

- (void)setFFlag:(NSString *)name value:(NSString *)value {
    [_fflags setObject:value forKey:name];
}

- (NSString *)getFFlag:(NSString *)name {
    return [_fflags objectForKey:name] ?: @"";
}

- (NSString *)base64Encode:(NSString *)input {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

- (NSString *)base64Decode:(NSString *)input {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:input options:0];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)websocketConnect:(NSString *)url {
    NSURL *wsURL = [NSURL URLWithString:url];
    NSURLSessionWebSocketTask *task = [[NSURLSession sharedSession] webSocketTaskWithURL:wsURL];
    [task resume];
    _websocket = task;
}

- (void)websocketSend:(NSString *)message {
    NSURLSessionWebSocketTask *task = _websocket;
    [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:message] 
    completionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[XZX] WebSocket send error: %@", error);
        }
    }];
}

- (void)websocketClose {
    NSURLSessionWebSocketTask *task = _websocket;
    [task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
    _websocket = nil;
}

- (id)getRenderProperty:(NSString *)property {
    return nil;
}

- (id)getHiddenProperty:(NSString *)property {
    return nil;
}

- (void)fireSignal:(NSString *)signal withArguments:(NSArray *)args {
    // Implementation
}

- (NSArray *)getConnections:(NSString *)signal {
    return @[];
}

- (void)deltaFunction:(NSString *)name args:(NSArray *)args {
    // Implementation
}

@end
