pub const CriticalSection = extern struct { debug_info: usize = 0, lock_count: i32 = 0, recursion_count: i32 = 0, owner: usize = 0, semaphore: usize = 0, spin_count: usize = 0 };
pub extern "kernel32" fn InitializeCriticalSection(*CriticalSection) callconv(.winapi) void;
pub extern "kernel32" fn EnterCriticalSection(*CriticalSection) callconv(.winapi) void;
pub extern "kernel32" fn TryEnterCriticalSection(*CriticalSection) callconv(.winapi) i32;
pub extern "kernel32" fn LeaveCriticalSection(*CriticalSection) callconv(.winapi) void;
pub extern "kernel32" fn InitOnceExecuteOnce(*usize, *const fn (*usize, usize, usize) callconv(.winapi) i32, usize, usize) callconv(.winapi) i32;
pub extern "kernel32" fn Sleep(u32) callconv(.winapi) void;
