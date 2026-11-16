pub inline fn restoreFx(fx: *const [512]u8) void {
    asm volatile ("fxrstor (%[buffer])"
        :
        : [buffer] "r" (fx),
        : .{ .memory = true, .xmm0 = true, .xmm1 = true, .xmm2 = true, .xmm3 = true, .xmm4 = true, .xmm5 = true, .xmm6 = true, .xmm7 = true });
}
pub const Environment = struct {
    fx: [512]u8 align(16),
    last_error: u32,
    pub inline fn capture(self: *Environment) void {
        asm volatile ("fxsave (%[buffer])"
            :
            : [buffer] "r" (&self.fx),
            : .{ .memory = true });
        self.last_error = asm volatile ("movl %%fs:52, %[value]"
            : [value] "=r" (-> u32),
            :
            : .{ .memory = true });
    }
    pub inline fn save(self: *Environment, mxcsr: *const u32) void {
        asm volatile ("fxsave (%[buffer]); fninit; ldmxcsr (%[mxcsr]); cld"
            :
            : [buffer] "r" (&self.fx),
              [mxcsr] "r" (mxcsr),
            : .{ .memory = true, .cc = true });
        self.last_error = asm volatile ("movl %%fs:52, %[value]"
            : [value] "=r" (-> u32),
            :
            : .{ .memory = true });
    }
    pub inline fn restore(self: *const Environment) void {
        restoreFx(&self.fx);
        asm volatile ("movl %[error_code], %%fs:52"
            :
            : [error_code] "r" (self.last_error),
            : .{ .memory = true });
    }
};
