#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static const NSInteger kDebounceThreshold = 2;

@interface XZXCore ()
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
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
        _overlayViewController = nil;
        _isInitialized = NO;
        _inGame = NO;
        _positiveCount = 0;
        _negativeCount = 0;
        monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        // Create invisible overlay (0.002 x 0.002 pixels)
        [self createInvisibleOverlay];
        
        [self startGameMonitoring];
    });
}

- (void)createInvisibleOverlay {
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) {
        NSLog(@"[XZX] No scene found");
        return;
    }
    
    UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
    if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
    if (!vc) {
        NSLog(@"[XZX] MainViewController not found");
        return;
    }
    
    self.overlayViewController = vc;
    
    if (!self.overlayWindow) {
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.rootViewController = vc;
        
        // CRITICAL: Invisible size
        self.overlayWindow.frame = CGRectMake(0, 0, 0.002, 0.002);
        self.overlayWindow.alpha = 0.01;
        self.overlayWindow.hidden = NO;
        
        NSLog(@"[XZX] Invisible overlay created");
    }
}

- (void)resizeOverlayToNormal {
    if (!self.overlayWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.overlayWindow.frame = screenBounds;
            self.overlayWindow.alpha = 1.0;
        }];
        
        // Notify ViewController to become visible
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXMakeVisible" object:nil];
        
        NSLog(@"[XZX] Overlay resized to full screen");
    });
}

- (void)shrinkOverlayToInvisible {
    if (!self.overlayWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Notify ViewController to hide first
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXMakeInvisible" object:nil];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.overlayWindow.frame = CGRectMake(0, 0, 0.002, 0.002);
            self.overlayWindow.alpha = 0.01;
        }];
        
        NSLog(@"[XZX] Overlay shrunk to invisible");
    });
}

// CRITICAL: This is the KEY function - checks Roblox's internal placeId
- (BOOL)isActuallyInGame {
    @try {
        // Try all possible DataModel class names
        NSArray *classNames = @[@"RobloxDataModel", @"RBXDataModel", @"DataModel"];
        Class dataModelClass = nil;
        for (NSString *name in classNames) {
            dataModelClass = NSClassFromString(name);
            if (dataModelClass) break;
        }
        if (!dataModelClass) return NO;
        
        // Get shared instance
        SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
        if (![dataModelClass respondsToSelector:sharedSel]) return NO;
        
        id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
        if (!dataModel) return NO;
        
        // Get placeId
        SEL placeIdSel = NSSelectorFromString(@"placeId");
        if (![dataModel respondsToSelector:placeIdSel]) return NO;
        
        id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
        BOOL inGame = (placeId && [placeId intValue] != 0);
        
        if (inGame) {
            NSLog(@"[XZX] placeId = %d - IN GAME", [placeId intValue]);
        } else {
            NSLog(@"[XZX] placeId = 0 or nil - NOT in game");
        }
        
        return inGame;
    } @catch (NSException *e) {
        NSLog(@"[XZX] isActuallyInGame error: %@", e);
        return NO;
    }
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Small initial delay for Roblox to load
        [NSThread sleepForTimeInterval:3.0];
        NSLog(@"[XZX] Monitoring for placeId > 0...");

        while (YES) {
            @autoreleasepool {
                BOOL inGameNow = [self isActuallyInGame];

                if (inGameNow) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] ✅ Game confirmed - showing UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self resizeOverlayToNormal];
                    });
                } else if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] ❌ Left game - hiding UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self shrinkOverlayToInvisible];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)viewHasMetalLayer:(UIView *)view {
    @try {
        if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        for (CALayer *sub in view.layer.sublayers ?: @[]) {
            if ([sub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            for (CALayer *subsub in sub.sublayers ?: @[]) {
                if ([subsub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            }
        }
        for (UIView *sub in view.subviews) {
            if ([self viewHasMetalLayer:sub]) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (void)showOverlay { [self resizeOverlayToNormal]; }
- (void)hideOverlay { [self shrinkOverlayToInvisible]; }
- (BOOL)isOverlayVisible { return _overlayWindow && _overlayWindow.alpha > 0.5; }
- (BOOL)isInGame { return _inGame; }

@end
