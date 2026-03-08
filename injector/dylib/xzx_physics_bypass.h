#ifndef XZX_PHYSICS_BYPASS_H
#define XZX_PHYSICS_BYPASS_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface XZXPhysicsBypass : NSObject
+ (instancetype)shared;
- (void)setTeleportGrace:(double)seconds;
- (void)respectForceField;
- (void)simulateServerAnchors;
- (void)validateWithRaycasts;
- (void)bypassSpeedDetection;
- (void)bypassFlyDetection;
- (void)bypassNoclipDetection;
- (void)bypassTeleportDetection;
- (void)gradualSpeedIncrease;
- (void)smoothTeleport;
- (void)simulatePhysicsLag;

@property (nonatomic, assign) BOOL hasForceField;
@property (nonatomic, assign) double lastTeleportTime;
@property (nonatomic, assign) CGPoint lastValidPosition;
@property (nonatomic, strong) NSMutableArray *movementHistory;
@end

#endif
