int game_read_current_level(void) {
    const char *area = *(const char *volatile *)0xfb4a20;
    if (!area) return -1;
    const char *level = *(const char *volatile *)(area + 0x220);
    return level ? *(const volatile short *)(level + 0x94) : -1;
}

int game_read_native_profile_ready(void) {
    const char *player = *(const char *volatile *)0xfb4940;
    if (!player || *(const volatile short *)(player + 0xdc0) < 0) return 0;
    const volatile unsigned *resource = *(const volatile unsigned *volatile *)(player + 0xf08);
    if (!resource) return 0;
    (void)*resource;
    return 1;
}
