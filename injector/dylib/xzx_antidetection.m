#import "xzx_antidetection.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <unistd.h>

static XZXAntiDetection *sharedAntiDetectionInstance = nil;

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
        _banProbability = 0.0;
    }
    return self;
}

- (void)initializeProtection {
    [self hideFromDyld];
    [self setupAntiDebug];
}

- (void)hideFromDyld {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "executor.dylib")) {
            uintptr_t header = (uintptr_t)_dyld_get_image_header(i);
            size_t size = 0;
            const uint8_t *cmd = (const uint8_t *)header + sizeof(struct mach_header_64);
            for (int j = 0; j < ((struct mach_header_64 *)header)->ncmds; j++) {
                struct load_command *lc = (struct load_command *)cmd;
                if (lc->cmd == LC_SEGMENT_64) {
                    struct segment_command_64 *seg = (struct segment_command_64 *)cmd;
                    if (strcmp(seg->segname, "__TEXT") == 0) {
                        size = seg->vmsize;
                        break;
                    }
                }
                cmd += lc->cmdsize;
            }
            if (size > 0) {
                vm_address_t addr = header;
                vm_protect(mach_task_self(), addr & ~(PAGE_SIZE - 1), size + PAGE_SIZE, 0,
                          VM_PROT_READ | VM_PROT_WRITE);
                memset((void *)header, 0, 0x100);
                vm_protect(mach_task_self(), addr & ~(PAGE_SIZE - 1), size + PAGE_SIZE, 0,
                          VM_PROT_READ | VM_PROT_EXECUTE);
            }
            break;
        }
    }
}

- (void)setupAntiDebug {
    void *handle = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_NOW);
    if (handle) {
        void *ptrace = dlsym(handle, "ptrace");
        if (ptrace) {
            vm_address_t addr = (vm_address_t)ptrace;
            vm_protect(mach_task_self(), addr & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
                      VM_PROT_READ | VM_PROT_WRITE);
            uint32_t ret = 0x00000020;
            memcpy(ptrace, &ret, 4);
            vm_protect(mach_task_self(), addr & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
                      VM_PROT_READ | VM_PROT_EXECUTE);
        }
        dlclose(handle);
    }
}

- (void)randomizeInjectionPattern {
    usleep((arc4random_uniform(500) + 100) * 1000);
}

- (void)cleanTraces {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"XZXExecutionHistory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isUnderInvestigation {
    int name[4];
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == 0) {
        if ((info.kp_proc.p_flag & P_TRACED) != 0) {
            _currentStrikes += 5;
            return YES;
        }
    }
    return NO;
}

- (void)emergencyShutdown {
    [self cleanTraces];
    exit(0);
}

@end
