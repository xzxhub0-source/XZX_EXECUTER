#import "xzx_core.h"
#import "XZX-Swift.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>

static XZXCore *sharedCoreInstance = nil;
static uintptr_t roblox_base = 0;
static uintptr_t datamodel_ptr = 0;
static int current_identity = 8;

@interface XZXCore () {
    BOOL _monitoringActive;
    dispatch_queue_t _monitorQueue;
}
@property (nonatomic, strong) NSMutableDictionary *originalMethods;
@property (nonatomic, assign) BOOL isInjected;
@end

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCoreInstance = [[XZXCore alloc] init];
    });
    return sharedCoreInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInGame = NO;
        _monitoringActive = NO;
        _originalMethods = [NSMutableDictionary dictionary];
        _isInjected = NO;
        _monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), 
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [[XZXCore shared] performSelector:@selector(inject) withObject:nil afterDelay:0];
    });
}

- (void)inject {
    if (_isInjected) return;
    _isInjected = YES;
    
    [self scanRobloxMemory];
    [self elevateThreadIdentity:8];
    [self hookRobloxMethods];
    [self startGameMonitoring];
    [self injectBootstrapScript];
}

- (void)scanRobloxMemory {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            
            uint8_t *datamodel_pattern = (uint8_t *)"\x48\x8B\x05\x00\x00\x00\x00\x48\x89\xC7\x48\x8B\x00\x00";
            for (int j = 0; j < 0x1000000; j++) {
                uintptr_t addr = roblox_base + j;
                if (memcmp((void *)addr, datamodel_pattern, 7) == 0) {
                    uint32_t offset = *(uint32_t *)(addr + 3);
                    datamodel_ptr = addr + 7 + offset;
                    datamodel_ptr = *(uintptr_t *)datamodel_ptr;
                    break;
                }
            }
            break;
        }
    }
}

- (void)elevateThreadIdentity:(int)identity {
    current_identity = identity;
    
    Class luaStateClass = NSClassFromString(@"RobloxLuaState");
    if (luaStateClass) {
        SEL getCurrentSel = NSSelectorFromString(@"currentState");
        if ([luaStateClass respondsToSelector:getCurrentSel]) {
            id luaState = ((id(*)(id, SEL))objc_msgSend)(luaStateClass, getCurrentSel);
            SEL setIdentitySel = NSSelectorFromString(@"setIdentity:");
            if (luaState && [luaState respondsToSelector:setIdentitySel]) {
                ((void(*)(id, SEL, int))objc_msgSend)(luaState, setIdentitySel, identity);
            }
        }
    }
}

- (void)hookRobloxMethods {
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (!dataModelClass) return;
    
    SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
    if (![dataModelClass respondsToSelector:sharedSel]) return;
    
    Method originalMethod = class_getClassMethod(dataModelClass, sharedSel);
    if (!originalMethod) return;
    
    IMP originalImp = method_getImplementation(originalMethod);
    [_originalMethods setObject:[NSValue valueWithPointer:originalImp] forKey:@"sharedDataModel"];
    
    IMP swizzledImp = imp_implementationWithBlock(^id(void) {
        if (current_identity != 8) {
            [self elevateThreadIdentity:8];
        }
        
        id (*originalFunc)(id, SEL) = (id(*)(id, SEL))originalImp;
        return originalFunc(dataModelClass, sharedSel);
    });
    
    class_replaceMethod(object_getClass(dataModelClass), sharedSel, swizzledImp, method_getTypeEncoding(originalMethod));
}

- (void)startGameMonitoring {
    if (_monitoringActive) return;
    _monitoringActive = YES;
    
    dispatch_async(_monitorQueue, ^{
        BOOL wasInGame = NO;
        while (self->_monitoringActive) {
            @autoreleasepool {
                BOOL isInGame = [self checkGameState];
                if (isInGame && !wasInGame) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self onGameJoined];
                    });
                } else if (!isInGame && wasInGame) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self onGameLeft];
                    });
                }
                wasInGame = isInGame;
            }
            usleep(500000);
        }
    });
}

- (BOOL)checkGameState {
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (!dataModelClass) return NO;
    
    SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
    if (![dataModelClass respondsToSelector:sharedSel]) return NO;
    
    id dataModel = ((id(*)(id, SEL))objc_msgSend)(dataModelClass, sharedSel);
    if (!dataModel) return NO;
    
    SEL placeIdSel = NSSelectorFromString(@"placeId");
    if (![dataModel respondsToSelector:placeIdSel]) return NO;
    
    id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
    return (placeId != nil);
}

- (void)injectBootstrapScript {
    Class luaStateClass = NSClassFromString(@"RobloxLuaState");
    if (!luaStateClass) return;
    
    SEL getCurrentSel = NSSelectorFromString(@"currentState");
    if (![luaStateClass respondsToSelector:getCurrentSel]) return;
    
    id luaState = ((id(*)(id, SEL))objc_msgSend)(luaStateClass, getCurrentSel);
    if (!luaState) return;
    
    SEL loadStringSel = NSSelectorFromString(@"loadString:");
    SEL pcallSel = NSSelectorFromString(@"pcall:args:results:msgh:");
    
    if (![luaState respondsToSelector:loadStringSel] || ![luaState respondsToSelector:pcallSel]) return;
    
    NSString *bootstrapCode = @"local gui = Instance.new('ScreenGui'); gui.Name = 'XZX_Executor'; gui.Parent = game:GetService('CoreGui'); gui.ResetOnSpawn = false; local frame = Instance.new('Frame'); frame.Size = UDim2.new(0, 400, 0, 500); frame.Position = UDim2.new(0.5, -200, 0.5, -250); frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30); frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true; frame.Parent = gui; local title = Instance.new('TextLabel'); title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundColor3 = Color3.fromRGB(30, 30, 40); title.Text = 'XZX Executor'; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.GothamBold; title.TextSize = 20; title.Parent = frame; local scriptBox = Instance.new('TextBox'); scriptBox.Size = UDim2.new(1, -20, 1, -90); scriptBox.Position = UDim2.new(0, 10, 0, 50); scriptBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50); scriptBox.TextColor3 = Color3.fromRGB(255, 255, 255); scriptBox.PlaceholderText = '-- Enter your script'; scriptBox.MultiLine = true; scriptBox.ClearTextOnFocus = false; scriptBox.Font = Enum.Font.Code; scriptBox.TextSize = 14; scriptBox.Parent = frame; local execute = Instance.new('TextButton'); execute.Size = UDim2.new(0.5, -5, 0, 30); execute.Position = UDim2.new(0, 10, 1, -40); execute.BackgroundColor3 = Color3.fromRGB(0, 255, 0); execute.Text = 'Execute'; execute.TextColor3 = Color3.fromRGB(0, 0, 0); execute.Font = Enum.Font.GothamBold; execute.TextSize = 16; execute.Parent = frame; local clear = Instance.new('TextButton'); clear.Size = UDim2.new(0.5, -5, 0, 30); clear.Position = UDim2.new(0.5, 5, 1, -40); clear.BackgroundColor3 = Color3.fromRGB(255, 0, 0); clear.Text = 'Clear'; clear.TextColor3 = Color3.fromRGB(255, 255, 255); clear.Font = Enum.Font.GothamBold; clear.TextSize = 16; clear.Parent = frame; execute.MouseButton1Click:Connect(function() local script = scriptBox.Text; if script and #script > 0 then local f, err = loadstring(script); if f then pcall(f) else warn('XZX Error: ' .. tostring(err)) end end end); clear.MouseButton1Click:Connect(function() scriptBox.Text = '' end);";
    
    int loadResult = ((int(*)(id, SEL, id))objc_msgSend)(luaState, loadStringSel, bootstrapCode);
    if (loadResult == 0) {
        ((void(*)(id, SEL, int, id, int, int))objc_msgSend)(luaState, pcallSel, 0, nil, 0, 0);
    }
}

- (void)onGameJoined {
    if (self.isInGame) return;
    self.isInGame = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.editorWindow) {
            MainViewController *vc = [[MainViewController alloc] init];
            self.editorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.editorWindow.windowLevel = UIWindowLevelAlert + 1;
            self.editorWindow.rootViewController = vc;
            self.editorWindow.backgroundColor = [UIColor clearColor];
        }
        self.editorWindow.hidden = NO;
        [self.editorWindow makeKeyAndVisible];
    });
    
    [self injectBootstrapScript];
}

- (void)onGameLeft {
    self.isInGame = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.editorWindow.hidden = YES;
    });
}

- (void)cleanupHooks {
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (dataModelClass) {
        NSValue *originalImpValue = _originalMethods[@"sharedDataModel"];
        if (originalImpValue) {
            IMP originalImp = [originalImpValue pointerValue];
            SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
            class_replaceMethod(object_getClass(dataModelClass), sharedSel, originalImp, method_getTypeEncoding(class_getClassMethod(dataModelClass, sharedSel)));
        }
    }
}

- (void)dealloc {
    [self cleanupHooks];
    if (_monitoringActive) {
        _monitoringActive = NO;
    }
}

void notify_game_joined(void) {
    [[XZXCore shared] onGameJoined];
}

void notify_game_left(void) {
    [[XZXCore shared] onGameLeft];
}

@end
