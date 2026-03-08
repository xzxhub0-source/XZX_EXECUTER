#ifndef XZX_EDITOR_H
#define XZX_EDITOR_H

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#define NEON_PURPLE [UIColor colorWithRed:0.8 green:0.2 blue:1.0 alpha:1.0]

@interface XZXEditor : NSObject
+ (instancetype)shared;
- (UIWindow *)createEditorWindow;
- (void)show;
- (void)hide;
- (void)executeScript;
- (void)clearScript;
- (void)saveScript;
- (void)loadScript;
- (void)loadScriptFromURL:(NSString *)url;
- (void)searchScriptBlox:(NSString *)query;

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITextView *scriptView;
@property (nonatomic, strong) NSMutableArray *savedScripts;
@end

#endif
