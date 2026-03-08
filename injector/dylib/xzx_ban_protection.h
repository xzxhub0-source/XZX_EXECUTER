#ifndef XZX_BAN_PROTECTION_H
#define XZX_BAN_PROTECTION_H

#import <Foundation/Foundation.h>

@interface XZXBanProtection : NSObject
+ (instancetype)shared;
- (void)protectAccount;
- (void)spoofHardwareID;
- (void)useAlternateAccount;
- (void)rotateAccounts;
- (BOOL)checkBanStatus;
- (void)detectBanWave;
- (void)emergencyLogout;
- (void)clearRobloxCache;
- (void)deleteLogs;
- (void)removeTraces;

@property (nonatomic, assign) BOOL isBanned;
@property (nonatomic, strong) NSString *currentHWID;
@property (nonatomic, strong) NSMutableArray *accountPool;
@end

#endif
