#ifndef XZX_FUNCTIONS_H
#define XZX_FUNCTIONS_H

#import <Foundation/Foundation.h>

// Forward declaration for Lua state
typedef struct lua_State lua_State;

@interface XZXFunctions : NSObject
+ (instancetype)shared;
- (void)executeLuaScript:(NSString *)script;

// FFlag functions
- (void)setFFlag:(NSString *)name value:(NSString *)value;
- (NSString *)getFFlag:(NSString *)name;

// Advanced functions
- (NSString *)base64Encode:(NSString *)input;
- (NSString *)base64Decode:(NSString *)input;
- (void)websocketConnect:(NSString *)url;
- (void)websocketSend:(NSString *)message;
- (void)websocketClose;

// Roblox-specific
- (id)getRenderProperty:(NSString *)property;
- (id)getHiddenProperty:(NSString *)property;
- (void)fireSignal:(NSString *)signal withArguments:(NSArray *)args;
- (NSArray *)getConnections:(NSString *)signal;

// Delta library compatibility
- (void)deltaFunction:(NSString *)name args:(NSArray *)args;

@property (nonatomic, strong) NSMutableDictionary *fflags;
@property (nonatomic, strong) id websocket;
@end

#endif
