#import "xzx_physics_bypass.h"

@implementation XZXPhysicsBypass

+ (instancetype)shared {
    static XZXPhysicsBypass *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZXPhysicsBypass alloc] init];
    });
    return instance;
}

- (void)setTeleportGrace:(double)seconds {}
- (void)respectForceField {}
- (void)simulateServerAnchors {}
- (void)validateWithRaycasts {}
- (void)bypassSpeedDetection {}
- (void)bypassFlyDetection {}
- (void)bypassNoclipDetection {}
- (void)bypassTeleportDetection {}
- (void)gradualSpeedIncrease {}
- (void)smoothTeleport {}
- (void)simulatePhysicsLag {}

@end
