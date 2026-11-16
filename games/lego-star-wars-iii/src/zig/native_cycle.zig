pub fn restarting(phase: u32, clock: u32, sequence: u32, initialized: bool) bool {
    return phase == 0xa and clock == 0 and sequence != 0 and initialized;
}
