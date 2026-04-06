#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "xzx_obfuscator.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedCore = [[self alloc] init];
    });
    return sharedCore;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _overlayWindow = nil;
        _isInitialized = NO;
        _inGame = NO;
        monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if ([UIApplication sharedApplication] == nil) return;
            InitLua();
            [self startGameMonitoring];
            NSLog(@"[XZX] Core initialized, monitoring for game join");
        });
    });
}

- (void)startGameMonitoring {
    dispatch_async(monitorQueue, ^{
        while (YES) {
            @autoreleasepool {
                BOOL currentlyInGame = [self checkIfInGame];
                
                if (currentlyInGame && !self.inGame) {
                    self.inGame = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                        NSLog(@"[XZX] Game detected - showing UI");
                    });
                } else if (!currentlyInGame && self.inGame) {
                    self.inGame = NO;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                        NSLog(@"[XZX] Left game - hiding UI");
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)checkIfInGame {
    @try {
        if ([UIApplication sharedApplication] == nil) return NO;
        
        const char* className = "\x8e\xf5\x9a\xc5\x86\xd1\x8c\xc3\x9c\xd8\x88\xc2\x91\xd7";
        const char* methodName = "\x93\xd1\x80\xce\x9d\xdb\x86\xc2\x9c\xc8\x95\xcf\x83\xcf";
        
        Class cls = xzx_getClass(className);
        if (cls) {
            SEL sel = xzx_getSelector(methodName);
            if ([cls respondsToSelector:sel]) {
                id dm = ((id(*)(id, SEL))objc_msgSend)((id)cls, sel);
                if (dm) {
                    const char* placeSelName = "\x95\xd0\x8f\xc7\x96\xd6";
                    SEL placeSel = xzx_getSelector(placeSelName);
                    if ([dm respondsToSelector:placeSel]) {
                        id pid = ((id(*)(id, SEL))objc_msgSend)(dm, placeSel);
                        return pid != nil;
                    }
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] Error checking game state: %@", e);
    }
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication] == nil) return;
        
        UIWindowScene *scene = (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        if (!scene) return;
        
        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) return;
        
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = YES;
        }
    });
}

- (BOOL)isOverlayVisible {
    return self.overlayWindow && !self.overlayWindow.hidden;
}

- (BOOL)isInGame {
    return _inGame;
}

@end
