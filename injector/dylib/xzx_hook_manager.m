#import "xzx_hook_manager.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>

static XZXHookManager *sharedHookManagerInstance = nil;
static int hook_counter = 0;

@implementation XZXHookManager

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHookManagerInstance = [[self alloc] init];
    });
    return sharedHookManagerInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hooks = [NSMutableDictionary dictionary];
        _originalFunctions = [NSMutableDictionary dictionary];
        _exposedHooks = [NSMutableArray array];
        _hookHistory = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)initializeHookSystem {
    [self obfuscateHookPointers];
    [self rotateHookPatterns];
    [self simulateNormalHooks];
}

- (void)addHook:(NSString *)functionName original:(void *)original hook:(void *)hook {
    if (functionName && hook) {
        NSValue *hookValue = [NSValue valueWithPointer:hook];
        _hooks[functionName] = hookValue;
        if (original) {
            NSValue *originalValue = [NSValue valueWithPointer:original];
            _originalFunctions[functionName] = originalValue;
        }
        hook_counter++;
        _hookHistory[@(hook_counter)] = @{
            @"function": functionName,
            @"timestamp": [NSDate date],
            @"hook_address": [NSString stringWithFormat:@"%p", hook]
        };
        if (_hookHistory.count > 50) {
            [_hookHistory removeObjectForKey:@(hook_counter - 50)];
        }
    }
}

- (void)removeHook:(NSString *)functionName {
    [_hooks removeObjectForKey:functionName];
}

- (void)restoreAllFunctions {
    for (NSString *key in _originalFunctions.allKeys) {
        [self restoreFunction:key];
    }
}

- (BOOL)areHooksExposed {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "Frida") || strstr(name, "substrate")) {
            return YES;
        }
    }
    return NO;
}

- (void)hideFromAdonis {
    for (NSString *key in _hooks.allKeys) {
        NSValue *hookValue = _hooks[key];
        void *hookPtr = [hookValue pointerValue];
        vm_address_t address = (vm_address_t)hookPtr;
        vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
                   VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

- (void)spoofConnectionList {
    static int spoofCounter = 0;
    spoofCounter++;
    NSArray *fakeConnections = @[
        @"rbxasset://",
        @"rbxassetid://",
        @"http://www.roblox.com",
        @"https://api.roblox.com"
    ];
    NSString *spoofedSignal = [NSString stringWithFormat:@"Signal_%d", spoofCounter];
    _exposedHooks = [NSMutableArray arrayWithArray:fakeConnections];
}

- (void)randomizeHookOrder {
    NSArray *allKeys = _hooks.allKeys;
    NSMutableArray *shuffled = [NSMutableArray arrayWithArray:allKeys];
    for (NSUInteger i = shuffled.count - 1; i > 0; i--) {
        [shuffled exchangeObjectAtIndex:i withObjectAtIndex:arc4random_uniform((uint32_t)i + 1)];
    }
    NSMutableDictionary *reordered = [NSMutableDictionary dictionary];
    for (NSString *key in shuffled) {
        reordered[key] = _hooks[key];
    }
    _hooks = reordered;
}

- (double)exposureRatio {
    if (_hooks.count == 0) return 0.0;
    NSArray *suspiciousPatterns = @[@"hook", @"detour", @"trampoline"];
    int exposed = 0;
    for (NSString *key in _hooks.allKeys) {
        for (NSString *pattern in suspiciousPatterns) {
            if ([key containsString:pattern]) {
                exposed++;
                break;
            }
        }
    }
    return (double)exposed / _hooks.count;
}

- (void *)cloneFunction:(void *)original {
    if (!original) return NULL;
    size_t size = 32;
    void *clone = mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                       MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    if (clone != MAP_FAILED) {
        memcpy(clone, original, size);
        __builtin___clear_cache(clone, (char *)clone + size);
        return clone;
    }
    return NULL;
}

- (void)restoreFunction:(NSString *)functionName {
    NSValue *originalValue = _originalFunctions[functionName];
    if (!originalValue) return;
    void *originalPtr = [originalValue pointerValue];
    NSValue *hookValue = _hooks[functionName];
    if (hookValue && originalPtr) {
        void *hookPtr = [hookValue pointerValue];
        vm_address_t address = (vm_address_t)hookPtr;
        vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        memcpy(hookPtr, originalPtr, 32);
        __builtin___clear_cache((char *)hookPtr, (char *)hookPtr + 32);
        vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
                   VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

- (NSString *)getFunctionHash:(void *)function {
    if (!function) return @"";
    unsigned char buffer[32];
    memcpy(buffer, function, 32);
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(buffer, 32, hash);
    NSMutableString *result = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", hash[i]];
    }
    return result;
}

- (NSArray *)getConnections:(NSString *)signal {
    NSMutableArray *connections = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        [connections addObject:@{
            @"signal": signal,
            @"handler": [NSString stringWithFormat:@"handler_%d", i],
            @"enabled": @YES
        }];
    }
    return connections;
}

- (void)fireSignal:(NSString *)signal withArguments:(NSArray *)args {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:signal
                                                            object:nil
                                                          userInfo:@{@"args": args}];
    });
}

- (NSArray *)getSignalArguments:(NSString *)signal {
    return @[];
}

- (BOOL)canSignalReplicate:(NSString *)signal {
    return YES;
}

- (void)replicateSignal:(NSString *)signal withArguments:(NSArray *)args {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self fireSignal:signal withArguments:args];
    });
}

- (void)obfuscateHookPointers {
    for (NSString *key in _hooks.allKeys) {
        NSValue *value = _hooks[key];
        void *ptr = [value pointerValue];
        uintptr_t addr = (uintptr_t)ptr;
        uintptr_t obfuscated = addr ^ 0xDEADBEEF;
        _hooks[key] = [NSValue valueWithPointer:(void *)obfuscated];
    }
}

- (void)rotateHookPatterns {
    NSArray *patterns = @[
        @[@"0x90", @"0x90", @"0x90"],
        @[@"0xE9", @"0x??", @"0x??"],
        @[@"0x48", @"0x8B", @"0x01"],
        @[@"0xFF", @"0x25", @"0x00"]
    ];
    int patternIndex = hook_counter % patterns.count;
    _exposedHooks = [NSMutableArray arrayWithArray:patterns[patternIndex]];
}

- (void)simulateNormalHooks {
    NSArray *normalFunctions = @[
        @"touchesBegan",
        @"touchesMoved",
        @"touchesEnded",
        @"viewDidLoad",
        @"applicationDidBecomeActive"
    ];
    for (NSString *func in normalFunctions) {
        if (!_hooks[func]) {
            _hooks[func] = [NSValue valueWithPointer:NULL];
        }
    }
}

@end
