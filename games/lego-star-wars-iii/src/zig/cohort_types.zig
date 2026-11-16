pub const Token = extern struct {
    owner: usize,
    owner_nonce: u32,
    cohort_nonce: u32,
    thread: u32,
    release: u32,
    epoch: u32,
    sequence: u32,
    frame: usize,
};
pub const Lease = extern struct { serial: u32, cohort: Token };
