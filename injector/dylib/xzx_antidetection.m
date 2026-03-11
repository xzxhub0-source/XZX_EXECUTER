#import "xzx_antidetection.h"
#import "xzx_memory_obfuscator.h"
#import "xzx_injection_randomizer.h"
#import "xzx_physics_bypass.h"
#import "xzx_hook_manager.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

static XZXAntiDetection *sharedAntiDetectionInstance = nil;
static uintptr_t current_datamodel_offset = 0;
static uintptr_t current_scriptcontext_offset = 0;
static uintptr_t current_luastate_offset = 0;

@implementation XZXAntiDetection

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAntiDetectionInstance = [[self alloc] init];
    });
    return sharedAntiDetectionInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentStrikes = 0;
        _maxStrikes = 15;
        _strikeReasons = [NSMutableDictionary dictionary];
        _banProbability = 0.0;
        _currentRobloxVersion = [self getRobloxVersion];
        [self loadOffsetsForVersion:_currentRobloxVersion];
    }
    return self;
}

- (NSString *)getRobloxVersion {
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!appVersion) {
        appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    }
    return appVersion ?: @"2.711.871";
}

- (void)loadOffsetsForVersion:(NSString *)version {
    NSDictionary *offsetDatabase = @{
        @"2.711.871": @{
            @"datamodel_offset": @0x12345678,
            @"scriptcontext_offset": @0x87654321,
            @"luastate_offset": @0x11223344,
            @"task_scheduler": @0xAABBCCDD,
            @"children_offset": @0x28,
            @"parent_offset": @0x30,
            @"name_offset": @0x38
        },
        @"2.710.000": @{
            @"datamodel_offset": @0x12345670,
            @"scriptcontext_offset": @0x87654320,
            @"luastate_offset": @0x11223340,
            @"task_scheduler": @0xAABBCCD0,
            @"children_offset": @0x28,
            @"parent_offset": @0x30,
            @"name_offset": @0x38
        }
    };
    
    self.versionOffsets = offsetDatabase[version] ?: offsetDatabase[@"2.711.871"];
    
    current_datamodel_offset = [self.versionOffsets[@"datamodel_offset"] unsignedLongValue];
    current_scriptcontext_offset = [self.versionOffsets[@"scriptcontext_offset"] unsignedLongValue];
    current_luastate_offset = [self.versionOffsets[@"luastate_offset"] unsignedLongValue];
}

- (void)updateOffsetsForVersion:(NSString *)version {
    [self loadOffsetsForVersion:version];
    [self randomizeInjectionPattern];
    [self obfuscateMemory];
}

- (void)initializeProtection {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self obfuscateMemory];
        [self hideFromMemoryScanners];
        [self spoofHardwareID];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self runIntegrityChecks];
            [self rotateDetectionPatterns];
        });
    });
}

- (void)runIntegrityChecks {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            if ([self isUnderInvestigation]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self emergencyShutdown];
                });
                break;
            }
            
            [self updateBanProbability];
            
            if ([self shouldSelfDestruct]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self emergencyShutdown];
                    exit(0);
                });
                break;
            }
            
            [NSThread sleepForTimeInterval:5.0];
        }
    });
}

- (BOOL)isUnderInvestigation {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "FLEX") || strstr(name, "Cycript") || strstr(name, "SSLKill")) {
            _currentStrikes += 3;
            return YES;
        }
    }
    
    NSArray *suspiciousProcesses = @[@"debugserver", @"gdb", @"lldb"];
    for (NSString *proc in suspiciousProcesses) {
        if (system([[NSString stringWithFormat:@"ps -A | grep %@", proc] UTF8String]) == 0) {
            _currentStrikes += 2;
            return YES;
        }
    }
    
    return NO;
}

- (void)emergencyShutdown {
    [self cleanHooks];
    [self cleanTraces];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"XZX Security"
                                                                       message:@"Security breach detected. Cleaning traces..."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [alert dismissViewControllerAnimated:YES completion:nil];
            });
        }];
    });
}

- (void)obfuscateMemory {
    [[XZXMemoryObfuscator shared] obfuscateAllSections];
    
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "executor.dylib")) {
            const struct mach_header *header = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            
            [[XZXMemoryObfuscator shared] encryptStringTable];
            [[XZXMemoryObfuscator shared] scrambleFunctionPointers];
            break;
        }
    }
}

- (void)randomizeInjectionPattern {
    [[XZXInjectionRandomizer shared] randomizeNextInjection];
    [[XZXInjectionRandomizer shared] randomizeInjectionTiming];
    [[XZXInjectionRandomizer shared] randomizeMemoryAllocation];
    [[XZXInjectionRandomizer shared] avoidSignaturePatterns];
}

- (void)spoofConnections {
    NSArray *connections = @[
        @"https://www.roblox.com",
        @"https://api.roblox.com",
        @"https://thumbnails.roblox.com"
    ];
    
    for (NSString *url in connections) {
        NSURL *spoofUrl = [NSURL URLWithString:url];
        NSURLRequest *request = [NSURLRequest requestWithURL:spoofUrl];
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:nil];
    }
}

- (void)cleanTraces {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"XZXExecutionHistory"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"XZXSavedScripts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths firstObject];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *cacheFiles = [fm contentsOfDirectoryAtPath:cachePath error:nil];
    
    for (NSString *file in cacheFiles) {
        if ([file hasPrefix:@"xzx_"] || [file containsString:@"executor"]) {
            [fm removeItemAtPath:[cachePath stringByAppendingPathComponent:file] error:nil];
        }
    }
}

- (void)bypassAdonis {
    [[XZXHookManager shared] hideFromAdonis];
    [[XZXHookManager shared] spoofConnectionList];
}

- (void)bypassKRX {
    [[XZXHookManager shared] randomizeHookOrder];
}

- (void)bypassSentinelAC {
    [self simulateNormalBehavior];
    [[XZXHookManager shared] hideFromAdonis];
}

- (void)bypassPhysicsChecks {
    [[XZXPhysicsBypass shared] setTeleportGrace:3.0];
    [[XZXPhysicsBypass shared] respectForceField];
    [[XZXPhysicsBypass shared] simulateServerAnchors];
    [[XZXPhysicsBypass shared] validateWithRaycasts];
}

- (void)updateBanProbability {
    _banProbability = (double)_currentStrikes / _maxStrikes;
    
    if (_banProbability > 0.7) {
        [self rotateDetectionPatterns];
        [self cleanTraces];
    }
}

- (BOOL)shouldSelfDestruct {
    return _banProbability > 0.95 || _currentStrikes >= _maxStrikes;
}

- (void)rotateDetectionPatterns {
    static int patternCounter = 0;
    patternCounter++;
    
    switch (patternCounter % 3) {
        case 0:
            [self spoofHardwareID];
            break;
        case 1:
            [self hideFromMemoryScanners];
            break;
        case 2:
            [self simulateNormalBehavior];
            break;
    }
}

- (void)spoofHardwareID {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *spoofedID = [NSString stringWithFormat:@"%08X-%04X-%04X-%04X-%08X%04X",
                           arc4random(), arc4random() & 0xFFFF,
                           arc4random() & 0xFFFF, arc4random() & 0xFFFF,
                           arc4random(), arc4random() & 0xFFFF];
    
    [defaults setObject:spoofedID forKey:@"XZXSpoofedID"];
    [defaults synchronize];
}

- (void)hideFromMemoryScanners {
    [[XZXMemoryObfuscator shared] preventMemoryDumping];
    [[XZXMemoryObfuscator shared] addDecoyFunctions];
    [[XZXMemoryObfuscator shared] createHoneyPot];
}

- (void)simulateNormalBehavior {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i = 0; i < 10; i++) {
            [NSThread sleepForTimeInterval:0.1 + (arc4random_uniform(100) / 100.0)];
        }
    });
}

@end
