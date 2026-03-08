#ifndef XZX_MEMORY_OBFUSCATOR_H
#define XZX_MEMORY_OBFUSCATOR_H

#import <Foundation/Foundation.h>

@interface XZXMemoryObfuscator : NSObject
+ (instancetype)shared;
- (void)obfuscateAllSections;
- (void)obfuscateDylibSections;
- (void)encryptStringTable;
- (void)scrambleFunctionPointers;
- (void)preventMemoryDumping;
- (void)addDecoyFunctions;
- (void)createHoneyPot;
- (NSString *)decryptString:(NSString *)encrypted withKey:(int)key;
- (NSString *)encryptString:(NSString *)plain withKey:(int)key;
- (BOOL)verifyMemoryIntegrity;
- (void)repairCorruptedSections;

@property (nonatomic, assign) BOOL isObfuscated;
@property (nonatomic, strong) NSMutableDictionary *stringTable;
@end

#endif
