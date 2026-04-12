#import "SRFXMemory.h"
#import <mach/mach.h>
#import <sys/mman.h>

static uint8_t obfuscation_key[16] = {
    0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
    0x13, 0x37, 0x42, 0x00, 0xFA, 0xCE, 0xFE, 0xED
};

@implementation SRFXMemory

+ (void)obfuscate {
    const struct mach_header *header = _dyld_get_image_header(0);
    if (!header) return;

    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    if (slide == 0) return;

    struct segment_command_64 *textSeg = NULL;
    uintptr_t cursor = (uintptr_t)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        struct load_command *cmd = (struct load_command *)cursor;
        if (cmd->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64 *)cmd;
            if (strcmp(seg->segname, "__TEXT") == 0) {
                textSeg = seg;
                break;
            }
        }
        cursor += cmd->cmdsize;
    }
    if (!textSeg) return;

    void *textStart = (void *)(textSeg->vmaddr + slide);
    size_t textSize = textSeg->vmsize;

    vm_address_t addr = (vm_address_t)textStart;
    vm_size_t size = textSize;
    vm_protect(mach_task_self(), addr, size, FALSE, VM_PROT_READ | VM_PROT_WRITE);

    for (size_t i = 0; i < size; i += 4096) {
        size_t pageSize = (i + 4096 <= size) ? 4096 : (size - i);
        [self encryptPage:(void *)(addr + i) size:pageSize];
    }

    vm_protect(mach_task_self(), addr, size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
}

+ (void)encryptPage:(void *)page size:(size_t)size {
    uint8_t *bytes = (uint8_t *)page;
    for (size_t i = 0; i < size; i++) {
        bytes[i] ^= obfuscation_key[i % 16];
    }
}

+ (void)decryptPage:(void *)page size:(size_t)size {
    [self encryptPage:page size:size];
}

@end
