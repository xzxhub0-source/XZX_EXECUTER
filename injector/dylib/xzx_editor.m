#import "xzx_editor.h"
#import "xzx_scriptblox.h"
#import "xzx_functions.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
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
    
    UIView *mainContainer = [[UIView alloc] initWithFrame:CGRectMake(40, 80, 400, 500)];
    mainContainer.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    mainContainer.layer.cornerRadius = 12;
    mainContainer.layer.borderColor = NEON_PURPLE.CGColor;
    mainContainer.layer.borderWidth = 2;
    mainContainer.layer.shadowColor = NEON_PURPLE.CGColor;
    mainContainer.layer.shadowOffset = CGSizeZero;
    mainContainer.layer.shadowRadius = 20;
    mainContainer.layer.shadowOpacity = 0.5;
    
    self.scriptView = [[UITextView alloc] initWithFrame:CGRectInset(mainContainer.bounds, 10, 10)];
    self.scriptView.backgroundColor = [UIColor clearColor];
    self.scriptView.textColor = NEON_PURPLE;
    self.scriptView.font = [UIFont fontWithName:@"Menlo" size:14];
    self.scriptView.text = @"-- XZX Executor\nprint('Hello World!')";
    
    [mainContainer addSubview:self.scriptView];
    [self.window.rootViewController.view addSubview:mainContainer];
    
    return self.window;
}

- (void)executeScript {
    NSString *script = self.scriptView.text;
    if (script.length > 0) {
        [[XZXFunctions shared] executeLuaScript:script];
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

- (void)loadScriptFromURL:(NSString *)url {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError *error = nil;
        NSString *script = [NSString stringWithContentsOfURL:[NSURL URLWithString:url] 
                                                    encoding:NSUTF8StringEncoding 
                                                       error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (script && script.length > 0) {
                self.scriptView.text = script;
            }
        });
    });
}

- (void)searchScriptBlox:(NSString *)query {
    // Will be implemented with ScriptBloxAPI
}

- (void)show {
    self.window.hidden = NO;
}

- (void)hide {
    self.window.hidden = YES;
}

@end
