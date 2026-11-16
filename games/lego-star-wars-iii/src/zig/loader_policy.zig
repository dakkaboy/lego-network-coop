pub fn jobsIdle(queued_before: u32, active_before: usize, queued_after: u32, active_after: usize) bool {
    return queued_before == 0 and active_before == 0 and queued_after == 0 and active_after == 0;
}
