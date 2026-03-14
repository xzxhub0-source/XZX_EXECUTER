#import "xzx_functions.h"

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
        _packetQueue = [NSMutableArray array];
        [self startRakNetMonitor];
    }
    return self;
}

- (void)executeLuaScript:(NSString *)script {
    NSLog(@"[XZX] Executing script");
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
    completionHandler:^(NSError *error) {}];
}

- (void)websocketClose {
    NSURLSessionWebSocketTask *task = _websocket;
    [task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
    _websocket = nil;
}

- (void)startRakNetMonitor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            [NSThread sleepForTimeInterval:0.1];
            
            if (arc4random_uniform(100) < 10) {
                NSMutableDictionary *packet = [NSMutableDictionary dictionary];
                packet[@"id"] = @(0x13);
                packet[@"timestamp"] = [NSDate date];
                
                @synchronized(self) {
                    [self.packetQueue addObject:packet];
                    if (self.packetQueue.count > 100) {
                        [self.packetQueue removeObjectsInRange:NSMakeRange(0, 50)];
                    }
                }
            }
        }
    });
}

- (id)rnetNextPacket {
    @synchronized(self) {
        if (self.packetQueue.count > 0) {
            id packet = self.packetQueue[0];
            [self.packetQueue removeObjectAtIndex:0];
            return packet;
        }
    }
    return nil;
}

- (id)rnetReadPacket:(id)packet {
    return packet;
}

- (void)rnetSendPacket:(id)packet {
    NSLog(@"[XZX] Sending packet");
}

- (void)rnetDesync:(int)amount {
    NSLog(@"[XZX] Desync set to %d", amount);
}

- (void)rnetReconnect {
    NSLog(@"[XZX] Reconnecting");
    @synchronized(self) {
        [self.packetQueue removeAllObjects];
    }
}

@end
