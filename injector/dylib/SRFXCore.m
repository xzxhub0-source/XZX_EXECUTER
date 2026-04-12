#import "SRFXCore.h"
#import "SRFXMainViewController.h"
#include "Core/SRFXLua.h"

static SRFXCore *instance = nil;

@interface SRFXCore ()
@property (nonatomic, assign) BOOL inGame;
@property (nonatomic, strong) NSTimer *checkTimer;
@end

@implementation SRFXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    self.inGame = NO;
    return self;
}

- (void)start {
    SRFXLuaInit();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self startGameDetection];
    });
}

- (void)startGameDetection {
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *t) {
        BOOL nowInGame = [self isInsideGame];
        if (nowInGame != self.inGame) {
            self.inGame = nowInGame;
            if (self.inGame) {
                [self showUI];
            } else {
                [self hideUI];
            }
        }
    }];
}

- (BOOL)isInsideGame {
    UIWindow *keyWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow) {
                    keyWindow = w;
                    break;
                }
            }
        }
    }
    if (!keyWindow) return NO;
    NSString *className = NSStringFromClass([keyWindow.rootViewController class]);
    NSArray *gameVCs = @[@"RBXGameViewController", @"GameViewController", @"RobloxGameController", @"RBXViewController"];
    for (NSString *vcName in gameVCs) {
        if ([className containsString:vcName]) return YES;
    }
    NSString *title = keyWindow.rootViewController.title ?: @"";
    if ([title containsString:@"Place"] || [title containsString:@"Game"]) return YES;
    if ([keyWindow.rootViewController respondsToSelector:@selector(childViewControllers)]) {
        for (UIViewController *child in keyWindow.rootViewController.childViewControllers) {
            NSString *childClass = NSStringFromClass([child class]);
            if ([childClass containsString:@"Game"] || [childClass containsString:@"RBX"]) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)showUI {
    if (self.uiWindow && !self.uiWindow.hidden) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) return;
    SRFXMainViewController *vc = [[SRFXMainViewController alloc] init];
    self.uiWindow = [[UIWindow alloc] initWithWindowScene:scene];
    self.uiWindow.windowLevel = UIWindowLevelAlert + 2;
    self.uiWindow.backgroundColor = [UIColor clearColor];
    self.uiWindow.rootViewController = vc;
    self.uiWindow.hidden = NO;
    [self.uiWindow makeKeyAndVisible];
}

- (void)hideUI {
    self.uiWindow.hidden = YES;
}

@end
