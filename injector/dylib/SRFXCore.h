#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface SRFXCore : NSObject
+ (instancetype)shared;
- (void)start;
- (void)showUI;
- (void)hideUI;
@property (nonatomic, strong) UIWindow *uiWindow;
@end
