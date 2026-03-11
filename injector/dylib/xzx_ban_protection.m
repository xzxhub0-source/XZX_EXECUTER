#import "xzx_ban_protection.h"
#import "xzx_memory_obfuscator.h"
#import "xzx_antidetection.h"
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

static XZXBanProtection *sharedBanProtectionInstance = nil;

@implementation XZXBanProtection

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedBanProtectionInstance = [[self alloc] init];
    });
    return sharedBanProtectionInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isBanned = NO;
        _accountPool = [NSMutableArray array];
        _actionHistory = [NSMutableArray array];
        _actionCount = 0;
        _lastActionTime = 0;
        [self getCurrentHWID];
        [self startBanMonitoring];
    }
    return self;
}

- (void)getCurrentHWID {
    @try {
        NSString *idfv = [UIDevice currentDevice].identifierForVendor.UUIDString;
        NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        
        NSString *hwid = [NSString stringWithFormat:@"%@%@", idfv ?: @"", idfa ?: @""];
        hwid = [self sha256Hash:hwid];
        
        _currentHWID = hwid ?: [self generateSpoofedHWID];
    } @catch (NSException *exception) {
        _currentHWID = [self generateSpoofedHWID];
    }
}

- (NSString *)sha256Hash:(NSString *)input {
    const char *str = [input UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(str, (CC_LONG)strlen(str), result);
    
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x", result[i]];
    }
    return ret;
}

- (NSString *)generateSpoofedHWID {
    NSMutableString *hwid = [NSMutableString string];
    for (int i = 0; i < 32; i++) {
        [hwid appendFormat:@"%02x", arc4random_uniform(256)];
    }
    return hwid;
}

- (void)startBanMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            [self detectBanWave];
            [self checkBanStatus];
            [NSThread sleepForTimeInterval:30.0];
        }
    });
}

- (void)protectAccount {
    [self spoofHardwareID];
    [self randomizeActionTiming];
    [self simulateHumanBehavior];
}

- (void)spoofHardwareID {
    NSString *newHWID = [self generateSpoofedHWID];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:newHWID forKey:@"XZXSpoofedHWID"];
    [defaults synchronize];
    
    _currentHWID = newHWID;
}

- (BOOL)checkBanStatus {
    NSURL *url = [NSURL URLWithString:@"https://www.roblox.com/Thumbs/avatar.ashx?x=100&y=100"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.0];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL banned = NO;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 403 || httpResponse.statusCode == 429) {
            banned = YES;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC));
    
    _isBanned = banned;
    return banned;
}

- (void)detectBanWave {
    static int checkCount = 0;
    checkCount++;
    
    if (checkCount % 10 == 0) {
        BOOL isBanned = [self checkBanStatus];
        if (isBanned) {
            [self emergencyLogout];
        }
    }
    
    NSArray *banIndicators = @[
        @"You were banned",
        @"Account has been disabled",
        @"termination",
        @"suspended"
    ];
    
    for (NSString *indicator in banIndicators) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:indicator]) {
            _isBanned = YES;
            [self emergencyLogout];
            break;
        }
    }
}

- (void)emergencyLogout {
    _isBanned = YES;
    
    [self clearRobloxCache];
    [self deleteLogs];
    [self removeTraces];
    
    [[XZXAntiDetection shared] emergencyShutdown];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *url = [NSURL URLWithString:@"https://www.roblox.com"];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    });
}

- (void)clearRobloxCache {
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryPath = paths.firstObject;
        if (!libraryPath) return;
        
        NSArray *cachePaths = @[
            [libraryPath stringByAppendingPathComponent:@"Caches/com.roblox.Roblox"],
            [libraryPath stringByAppendingPathComponent:@"Preferences/com.roblox.Roblox.plist"],
            [libraryPath stringByAppendingPathComponent:@"Application Support/com.roblox.Roblox"],
            [libraryPath stringByAppendingPathComponent:@"WebKit/com.roblox.Roblox"]
        ];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *path in cachePaths) {
            if ([fm fileExistsAtPath:path]) {
                [fm removeItemAtPath:path error:nil];
            }
        }
        
        NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        NSArray *caches = [fm contentsOfDirectoryAtPath:cachesPath error:nil];
        for (NSString *file in caches) {
            if ([file containsString:@"roblox"] || [file containsString:@"Roblox"]) {
                [fm removeItemAtPath:[cachesPath stringByAppendingPathComponent:file] error:nil];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Cache clear error: %@", exception);
    }
}

- (void)deleteLogs {
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docPath = paths.firstObject;
        if (!docPath) return;
        
        NSString *logPath = [docPath stringByAppendingPathComponent:@"xzx_logs"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
        }
        
        NSString *crashLogs = [docPath stringByAppendingPathComponent:@"crashlogs"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:crashLogs]) {
            [[NSFileManager defaultManager] removeItemAtPath:crashLogs error:nil];
        }
        
        NSString *tmpPath = NSTemporaryDirectory();
        NSArray *tmpFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpPath error:nil];
        for (NSString *file in tmpFiles) {
            if ([file hasPrefix:@"xzx_"] || [file containsString:@"executor"]) {
                [[NSFileManager defaultManager] removeItemAtPath:[tmpPath stringByAppendingPathComponent:file] error:nil];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Log deletion error: %@", exception);
    }
}

- (void)removeTraces {
    [self clearRobloxCache];
    [self deleteLogs];
    
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)useAlternateAccount {
    if (_accountPool.count > 0) {
        NSString *altAccount = _accountPool[arc4random_uniform((uint32_t)_accountPool.count)];
        [[NSUserDefaults standardUserDefaults] setObject:altAccount forKey:@"XZXAltAccount"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)rotateAccounts {
    if (_accountPool.count > 1) {
        NSMutableArray *rotated = [NSMutableArray array];
        NSUInteger start = arc4random_uniform((uint32_t)_accountPool.count);
        
        for (NSUInteger i = 0; i < _accountPool.count; i++) {
            [rotated addObject:_accountPool[(start + i) % _accountPool.count]];
        }
        
        _accountPool = rotated;
    }
}

- (void)updateBanPatterns {
    _actionCount = 0;
    _lastActionTime = [NSDate timeIntervalSinceReferenceDate];
    [_actionHistory removeAllObjects];
}

- (void)simulateHumanBehavior {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        int actions = arc4random_uniform(5) + 1;
        
        for (int i = 0; i < actions; i++) {
            [self randomizeActionTiming];
            
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            [_actionHistory addObject:@(now - _lastActionTime)];
            _lastActionTime = now;
            _actionCount++;
            
            if (_actionHistory.count > 20) {
                [_actionHistory removeObjectAtIndex:0];
            }
        }
    });
}

- (void)randomizeActionTiming {
    NSTimeInterval baseDelay = 0.5;
    NSTimeInterval randomDelay = (arc4random_uniform(100) / 100.0) * 2.0;
    
    if (_actionHistory.count > 0) {
        NSNumber *avg = [_actionHistory valueForKeyPath:@"@avg.self"];
        baseDelay = MAX(0.3, avg.doubleValue * 0.8);
    }
    
    usleep((baseDelay + randomDelay) * 1000000);
}

- (void)avoidPatternRecognition {
    if (_actionHistory.count > 10) {
        double avg = [[_actionHistory valueForKeyPath:@"@avg.self"] doubleValue];
        double variance = 0;
        
        for (NSNumber *time in _actionHistory) {
            variance += pow(time.doubleValue - avg, 2);
        }
        variance /= _actionHistory.count;
        
        if (variance < 0.1) {
            [self randomizeActionTiming];
            usleep(arc4random_uniform(500000));
        }
    }
}

@end
