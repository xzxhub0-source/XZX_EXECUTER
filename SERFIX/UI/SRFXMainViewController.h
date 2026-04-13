#import <UIKit/UIKit.h>

@interface SRFXMainViewController : UIViewController

@property (nonatomic, strong) UITextView      *editor;
@property (nonatomic, strong) UITableView     *scriptList;
@property (nonatomic, strong) NSMutableArray  *scripts;
@property (nonatomic, strong) UITextView      *consoleView;
@property (nonatomic, strong) NSMutableString *consoleText;
@property (nonatomic, assign) NSInteger        selectedTab;

// Floating drag button (shown when panel is hidden)
@property (nonatomic, strong) UIButton        *floatBtn;

@end
