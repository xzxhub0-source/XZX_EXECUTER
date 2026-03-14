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

@property (nonatomic, assign) NSInteger currentStrikes;
@property (nonatomic, assign) NSInteger maxStrikes;
@property (nonatomic, assign) double banProbability;
@end

#endif
