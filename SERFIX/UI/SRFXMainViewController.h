#import <UIKit/UIKit.h>
@interface SRFXMainViewController : UIViewController
@property (nonatomic, strong) UITextView *editor;
@property (nonatomic, strong) UITableView *scriptList;
@property (nonatomic, strong) NSMutableArray *scripts;
@property (nonatomic, strong) UIView *tabBar;
@property (nonatomic, assign) NSInteger selectedTab;
@end
