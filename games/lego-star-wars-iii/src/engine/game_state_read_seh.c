#include "game_state.h"

unsigned long __cdecl _exception_code(void);
#pragma intrinsic(_exception_code)

// Keep native reads in a separate translation unit so x86 Clang emits the SEH registration.
int game_read_current_level(void);
int game_read_native_profile_ready(void);

static int memory_read_fault(unsigned long code) {
    return code == 0xc0000005ul || code == 0xc0000006ul;
}

int game_current_level(void) {
    __try {
        return game_read_current_level();
    } __except (memory_read_fault(_exception_code())) {
        return -1;
    }
}

int game_native_profile_ready(void) {
    __try {
        return game_read_native_profile_ready();
    } __except (memory_read_fault(_exception_code())) {
        return 0;
    }
}
