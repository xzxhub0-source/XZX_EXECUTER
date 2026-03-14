#import "xzx_editor.h"
#import "xzx_functions.h"
#import "Core/LuaExecutor.h"
#import <QuartzCore/QuartzCore.h>

static XZXEditor *sharedEditorInstance = nil;

@implementation XZXEditor

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEditorInstance = [[self alloc] init];
    });
    return sharedEditorInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _savedScripts = [NSMutableArray array];
    }
    return self;
}

- (UIWindow *)createEditorWindow {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    self.window = [[UIWindow alloc] initWithFrame:screenBounds];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.rootViewController = [UIViewController new];
    self.window.rootViewController.view.backgroundColor = [UIColor clearColor];
    self.window.hidden = YES;
    
    UIView *mainContainer = [[UIView alloc] initWithFrame:CGRectMake(40, 40, screenBounds.size.width - 80, screenBounds.size.height - 80)];
    mainContainer.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    mainContainer.layer.cornerRadius = 16;
    mainContainer.layer.borderColor = NEON_PURPLE.CGColor;
    mainContainer.layer.borderWidth = 2;
    
    self.scriptView = [[UITextView alloc] initWithFrame:CGRectInset(mainContainer.bounds, 10, 10)];
    self.scriptView.backgroundColor = [UIColor clearColor];
    self.scriptView.textColor = NEON_PURPLE;
    self.scriptView.font = [UIFont fontWithName:@"Menlo" size:14];
    self.scriptView.text = @"-- XZX Executor\nprint('Hello World!')";
    [mainContainer addSubview:self.scriptView];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(mainContainer.frame.size.width - 60, 10, 50, 50);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:NEON_PURPLE forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:24];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [mainContainer addSubview:closeBtn];
    
    [self.window.rootViewController.view addSubview:mainContainer];
    
    return self.window;
}

- (void)executeScript {
    NSString *script = self.scriptView.text;
    if (script.length > 0) {
        ExecuteScript(script);
    }
}

- (void)clearScript {
    self.scriptView.text = @"";
}

- (void)saveScript {
    if (self.scriptView.text.length > 0) {
        [_savedScripts addObject:self.scriptView.text];
        [[NSUserDefaults standardUserDefaults] setObject:_savedScripts forKey:@"XZXSavedScripts"];
    }
}

- (void)loadScript {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"XZXSavedScripts"];
    if (saved.count > 0) {
        self.scriptView.text = [saved lastObject];
    }
}

- (void)show {
    self.window.hidden = NO;
}

- (void)hide {
    self.window.hidden = YES;
}

@end
