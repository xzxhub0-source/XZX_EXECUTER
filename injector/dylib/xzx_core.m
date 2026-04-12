#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static const NSTimeInterval kStartupDelay = 5.0;
static const NSTimeInterval kPollInterval = 1.0;
static const NSInteger kDebounce = 2;

@interface XZXCore ()
// DO NOT redeclare overlayWindow - it's already in the header
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@property (nonatomic, assign) BOOL inGame;
@end

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sharedCore = [[self alloc] init]; });
    return sharedCore;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _overlayWindow = nil;
        _isInitialized = NO;
        _inGame = NO;
        _positiveCount = 0;
        _negativeCount = 0;
    }
    return self;
}

- (void)startEngine {
    if (_isInitialized) return;
    _isInitialized = YES;
    InitLua();
    NSLog(@"[XZX] Lua initialized. Starting detection in %.0fs.", kStartupDelay);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kStartupDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self schedulePoll]; });
}

- (void)schedulePoll {
    [self pollOnce];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPollInterval * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self schedulePoll]; });
}

- (void)pollOnce {
    BOOL isInGameNow = [self isPlayerInGame];
    if (isInGameNow) { _positiveCount++; _negativeCount = 0; }
    else             { _negativeCount++; _positiveCount = 0; }

    if (!_inGame && _positiveCount >= kDebounce) {
        _inGame = YES;
        _positiveCount = 0;
        _negativeCount = 0;
        NSLog(@"[XZX] In-game detected — showing overlay");
        [self showOverlay];
    } else if (_inGame && _negativeCount >= kDebounce) {
        _inGame = NO;
        _positiveCount = 0;
        _negativeCount = 0;
        NSLog(@"[XZX] Left game — hiding overlay");
        [self hideOverlay];
    }
}

- (BOOL)isPlayerInGame {
    @try {
        Class dataModelClass = NSClassFromString(@"RobloxDataModel");
        if (!dataModelClass) dataModelClass = NSClassFromString(@"RBXDataModel");
        if (!dataModelClass) return NO;

        SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
        if (![dataModelClass respondsToSelector:sharedSel]) return NO;
        id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
        if (!dataModel) return NO;

        SEL placeIdSel = NSSelectorFromString(@"placeId");
        if (![dataModel respondsToSelector:placeIdSel]) return NO;
        id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
        return (placeId && [placeId intValue] != 0);
    } @catch (NSException *e) {
        return NO;
    }
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }
    if (!scene) return;
    XZXMainViewController *vc = [[XZXMainViewController alloc] init];
    _overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
    _overlayWindow.windowLevel = UIWindowLevelAlert + 1;
    _overlayWindow.backgroundColor = [UIColor clearColor];
    _overlayWindow.rootViewController = vc;
    _overlayWindow.hidden = NO;
    [_overlayWindow makeKeyAndVisible];
    NSLog(@"[XZX] Overlay shown");
}

- (void)hideOverlay { if (_overlayWindow) _overlayWindow.hidden = YES; }

@end
