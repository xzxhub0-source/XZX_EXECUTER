#ifndef XZX_ANTIDETECTION_H
#define XZX_ANTIDETECTION_H

#import <Foundation/Foundation.h>

@interface XZXAntiDetection : NSObject
+ (instancetype)shared;
- (void)initializeProtection;
- (void)runIntegrityChecks;
- (BOOL)isUnderInvestigation;
- (void)emergencyShutdown;
- (void)obfuscateMemory;
- (void)randomizeInjectionPattern;
- (void)spoofConnections;
- (void)cleanTraces;
- (void)bypassAdonis;
- (void)bypassKRX;
- (void)bypassSentinelAC;
- (void)bypassPhysicsChecks;
- (void)updateBanProbability;
- (BOOL)shouldSelfDestruct;
- (void)updateOffsetsForVersion:(NSString *)version;
- (void)rotateDetectionPatterns;
- (void)spoofHardwareID;
- (void)hideFromMemoryScanners;
- (void)simulateNormalBehavior;

@property (nonatomic, assign) NSInteger currentStrikes;
@property (nonatomic, assign) NSInteger maxStrikes;
@property (nonatomic, strong) NSMutableDictionary *strikeReasons;
@property (nonatomic, assign) double banProbability;
@property (nonatomic, strong) NSString *currentRobloxVersion;
@property (nonatomic, strong) NSDictionary *versionOffsets;
@end

#endif
