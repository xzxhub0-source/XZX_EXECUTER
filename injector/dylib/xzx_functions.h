#ifndef XZX_FUNCTIONS_H
#define XZX_FUNCTIONS_H

#import <Foundation/Foundation.h>

@interface XZXFunctions : NSObject
+ (instancetype)shared;
- (void)executeLuaScript:(NSString *)script;
- (void)setFFlag:(NSString *)name value:(NSString *)value;
- (NSString *)getFFlag:(NSString *)name;
- (NSString *)base64Encode:(NSString *)input;
- (NSString *)base64Decode:(NSString *)input;
- (void)websocketConnect:(NSString *)url;
- (void)websocketSend:(NSString *)message;
- (void)websocketClose;
- (id)rnetNextPacket;
- (id)rnetReadPacket:(id)packet;
- (void)rnetSendPacket:(id)packet;
- (void)rnetDesync:(int)amount;
- (void)rnetReconnect;

@property (nonatomic, strong) NSMutableDictionary *fflags;
@property (nonatomic, strong) id websocket;
@property (nonatomic, strong) NSMutableArray *packetQueue;
@end

#endif
