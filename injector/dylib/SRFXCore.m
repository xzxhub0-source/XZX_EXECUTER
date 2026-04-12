#import "SRFXCore.h"
#import "SRFXMainViewController.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include "Core/SRFXLua.h"

static SRFXCore *instance = nil;
static const NSInteger kDebounce = 3;

@implementation SRFXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _inGame        = NO;
        _uiWindow      = nil;
        _positiveCount = 0;
        _negativeCount = 0;
    }
    return self;
}

- (void)start {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        SRFXLuaInit();
        [self startGameDetection];
    });
}

- (void)startGameDetection {
    __weak typeof(self) weak = self;
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:1.2
                                                      repeats:YES
                                                        block:^(NSTimer *t) {
        __strong typeof(self) self = weak;
        if (!self) { [t invalidate]; return; }

        BOOL nowInGame = [self isInsideGame];

        if (nowInGame) { self.positiveCount++; self.negativeCount  = 0; }
        else           { self.negativeCount++; self.positiveCount  = 0; }

        if (!self.inGame && self.positiveCount >= kDebounce) {
            self.inGame = YES;
            self.positiveCount = 0;
            [self showUI];
        } else if (self.inGame && self.negativeCount >= kDebounce) {
            self.inGame = NO;
            self.negativeCount = 0;
            [self hideUI];
        }
    }];
}

- (BOOL)isInsideGame {
    @try {
        NSArray *classNames = @[@"RBXDataModel", @"RobloxDataModel", @"DataModel"];
        Class dmClass = nil;
        for (NSString *n in classNames) {
            dmClass = NSClassFromString(n);
            if (dmClass) break;
        }
        if (!dmClass) return NO;

        NSArray *sharedSels = @[@"sharedDataModel", @"shared", @"singleton"];
        id dm = nil;
        for (NSString *sn in sharedSels) {
            SEL s = NSSelectorFromString(sn);
            if ([dmClass respondsToSelector:s]) {
                dm = ((id(*)(id,SEL))objc_msgSend)((id)dmClass, s);
                if (dm) break;
            }
        }
        if (!dm) return NO;

        NSArray *placeSelNames = @[@"placeId", @"PlaceId", @"currentPlaceId"];
        for (NSString *sn in placeSelNames) {
            SEL s = NSSelectorFromString(sn);
            if ([dm respondsToSelector:s]) {
                id pid = ((id(*)(id,SEL))objc_msgSend)(dm, s);
                return pid && [pid intValue] != 0;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[SRFX] isInsideGame error: %@", e);
    }
    return NO;
}

- (void)showUI {
    if (!self.inGame) return;
    if (self.uiWindow && !self.uiWindow.hidden) return;

    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{ [self showUI]; });
        return;
    }

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s; break;
        }
    }
    if (!scene)
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    if (!scene) return;

    if (!self.uiWindow) {
        SRFXMainViewController *vc = [[SRFXMainViewController alloc] init];
        self.uiWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.uiWindow.windowLevel = UIWindowLevelAlert + 5;
        self.uiWindow.backgroundColor = UIColor.clearColor;
        self.uiWindow.hidden = YES;
        self.uiWindow.rootViewController = vc;
    }

    self.uiWindow.hidden = NO;
    [self.uiWindow makeKeyAndVisible];
}

- (void)hideUI {
    if (!self.uiWindow) return;
    self.uiWindow.hidden = YES;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            UIWindow *rw = ((UIWindowScene *)s).windows.firstObject;
            if (rw && rw != self.uiWindow) { [rw makeKeyWindow]; break; }
        }
    }
}

@end
