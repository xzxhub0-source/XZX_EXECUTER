#ifndef XZX_CORE_H
#define XZX_CORE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class XZXEditor;

@interface XZXCore : NSObject
+ (instancetype)shared;
- (void)initialize;
- (void)onGameJoined;
- (void)onGameLeft;
@property (nonatomic, assign) BOOL isInGame;
@property (nonatomic, strong) UIWindow *editorWindow;
@end

void notify_game_joined(void);
void notify_game_left(void);

#endif
