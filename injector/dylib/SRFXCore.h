#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SRFXCore : NSObject
+ (instancetype)shared;
- (void)start;
- (void)showUI;
- (void)hideUI;

@property (nonatomic, strong) UIWindow *uiWindow;
@property (nonatomic, assign) BOOL inGame;
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@end
