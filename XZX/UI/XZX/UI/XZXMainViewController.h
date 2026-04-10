#import <UIKit/UIKit.h>

@interface XZXMainViewController : UIViewController
@property (nonatomic, strong) UIView      *panel;
@property (nonatomic, strong) UITextView  *textView;
@property (nonatomic, strong) UIView      *editorView;
@property (nonatomic, strong) UIView      *hubView;
@property (nonatomic, strong) UIView      *savedView;
@property (nonatomic, strong) UIView      *tabLine;
@property (nonatomic, strong) UIButton    *toggleBtn;
@property (nonatomic, strong) NSMutableArray *tabButtons;
@property (nonatomic, assign) BOOL        panelVisible;
@end
