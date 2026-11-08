#include "../src/sync/profile_bootstrap_state.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>

static unsigned checks;
static void require(bool value) {
    ++checks;
    if (!value) { std::fprintf(stderr, "profile bootstrap check %u failed\n", checks); std::abort(); }
}
static uint32_t native_checksum(const void *data, size_t size) {
    auto *bytes = static_cast<const uint8_t *>(data);
    uint32_t value = 2166136261u;
    for (size_t i = 0; i < size; ++i) value = (value ^ bytes[i]) * 16777619u;
    return value;
}
static void make_data(uint8_t *data, uint32_t salt) {
    for (size_t i = 0; i < SYNC_PROFILE_BYTES; ++i) data[i] = static_cast<uint8_t>((i * 37 + salt) ^ (i >> 7));
    const uint32_t magic = 0x500;
    std::memcpy(data, &magic, 4);
}
int main() {
    static_assert(sizeof(ProfileBootstrapContext) == 12);
    static_assert(sizeof(ProfileBootstrapClientState) == 16);
    ProfileBootstrapContext context{17, 3, 9};
    ProfileBootstrapHostState host{};
    ProfileBootstrapClientState client{};
    static uint8_t data[SYNC_PROFILE_BYTES];
    make_data(data, 71);
    require(profile_bootstrap_context_valid(&context));
    require(!profile_bootstrap_context_valid(nullptr));
    require(!profile_bootstrap_host_initial(&host, &context));
    require(!profile_bootstrap_host_capture(&host, &context, data, sizeof data, 0));
    require(!profile_bootstrap_client_should_apply(&client, &context, 0));
    require(!profile_bootstrap_client_is_applied(&client, &context));
    require(!profile_bootstrap_client_mark_applied(&client, &context));
    require(profile_bootstrap_host_bind(&host, &context));
    require(profile_bootstrap_client_bind(&client, &context));
    const auto empty_host = host;
    for (unsigned field = 0; field < 5; ++field) {
        auto bad = context;
        if (field == 0) bad.session = 0;
        if (field == 1) bad.session = UINT32_MAX;
        if (field == 2) bad.epoch = 0;
        if (field == 3) bad.level = -1;
        if (field == 4) bad.level = 4096;
        require(!profile_bootstrap_context_valid(&bad));
        require(!profile_bootstrap_host_bind(&host, &bad));
        require(!std::memcmp(&host, &empty_host, sizeof host));
        require(!profile_bootstrap_client_bind(&client, &bad));
        require(!profile_bootstrap_client_should_apply(&client, &bad, 1));
    }
    require(!profile_bootstrap_host_capture(&host, &context, nullptr, sizeof data, 0));
    require(!profile_bootstrap_host_capture(&host, &context, data, 0, 0));
    require(!profile_bootstrap_host_capture(&host, &context, data, sizeof data - 1, 0));
    require(!profile_bootstrap_host_capture(&host, &context, data, sizeof data + 1, 0));
    data[0] ^= 1;
    require(!profile_bootstrap_host_capture(&host, &context, data, sizeof data, 0));
    data[0] ^= 1;
    require(!std::memcmp(&host, &empty_host, sizeof host));
    require(profile_bootstrap_host_capture(&host, &context, data, sizeof data, 0));
    const auto captured = host;
    const auto *initial = profile_bootstrap_host_initial(&host, &context);
    require(initial && initial->epoch == context.epoch && initial->level == context.level && initial->sequence == 0);
    require(initial->checksum == native_checksum(data, sizeof data));
    require(!std::memcmp(initial->data, data, sizeof data));
    require(profile_bootstrap_profile_valid(initial, &context));
    require(profile_bootstrap_host_capture(&host, &context, data, sizeof data, 0));
    require(profile_bootstrap_host_bind(&host, &context));
    require(!std::memcmp(&host, &captured, sizeof host));
    data[0xb57c + 21] ^= 2;
    require(!profile_bootstrap_host_capture(&host, &context, data, sizeof data, 1));
    require(!std::memcmp(&host, &captured, sizeof host));
    require(profile_bootstrap_host_initial(&host, &context)->data[0xb57c + 21] != data[0xb57c + 21]);
    data[0xb57c + 21] ^= 2;
    require(!profile_bootstrap_host_capture(&host, &context, data, sizeof data, 1));
    require(!std::memcmp(&host, &captured, sizeof host));
    for (unsigned field = 0; field < 4; ++field) {
        SyncProfile malformed = host.initial;
        if (field == 0) ++malformed.epoch;
        if (field == 1) ++malformed.level;
        if (field == 2) malformed.data[0] ^= 1;
        if (field == 3) malformed.data[0x40] ^= 1;
        require(!profile_bootstrap_profile_valid(&malformed, &context));
    }
    require(!profile_bootstrap_profile_valid(nullptr, &context));
    require(profile_bootstrap_client_should_apply(&client, &context, 0));
    require(profile_bootstrap_client_accepts_packet(&client, &context, &host.initial, 0));
    require(profile_bootstrap_client_accepts_packet(&client, &context, &host.initial, 1));
    auto premature_live = host.initial;
    premature_live.sequence = 1;
    require(!profile_bootstrap_client_accepts_packet(&client, &context, &premature_live, 0));
    require(!profile_bootstrap_client_accepts_packet(&client, &context, &premature_live, 1));
    const auto before_decision = client;
    require(profile_bootstrap_client_should_apply(&client, &context, 0));
    require(!std::memcmp(&client, &before_decision, sizeof client));
    require(profile_bootstrap_client_mark_applied(&client, &context));
    require(profile_bootstrap_client_is_applied(&client, &context));
    require(!profile_bootstrap_client_accepts_packet(&client, &context, &host.initial, 0));
    require(!profile_bootstrap_client_accepts_packet(&client, &context, &host.initial, 1));
    require(!profile_bootstrap_client_accepts_packet(&client, &context, &premature_live, 0));
    require(profile_bootstrap_client_accepts_packet(&client, &context, &premature_live, 1));
    require(!profile_bootstrap_client_should_apply(&client, &context, 0));
    require(profile_bootstrap_client_mark_applied(&client, &context));
    require(profile_bootstrap_client_bind(&client, &context));
    require(!profile_bootstrap_client_should_apply(&client, &context, 0));
    for (unsigned i = 0; i < 20; ++i) require(profile_bootstrap_client_should_apply(&client, &context, 1));
    for (unsigned field = 0; field < 3; ++field) {
        auto foreign = context;
        if (field == 0) ++foreign.session;
        if (field == 1) ++foreign.epoch;
        if (field == 2) ++foreign.level;
        const auto before_client = client;
        require(!profile_bootstrap_host_capture(&host, &foreign, data, sizeof data, 0));
        require(!profile_bootstrap_host_initial(&host, &foreign));
        require(!profile_bootstrap_profile_valid(&host.initial, &foreign) || field == 0);
        require(!profile_bootstrap_client_should_apply(&client, &foreign, 0));
        require(!profile_bootstrap_client_should_apply(&client, &foreign, 1));
        require(!profile_bootstrap_client_is_applied(&client, &foreign));
        require(!profile_bootstrap_client_accepts_packet(&client, &foreign, &host.initial, 1));
        require(!profile_bootstrap_client_mark_applied(&client, &foreign));
        require(!std::memcmp(&client, &before_client, sizeof client));
        require(!std::memcmp(&host, &captured, sizeof host));
    }
    for (unsigned field = 0; field < 3; ++field) {
        auto next = context;
        if (field == 0) ++next.session;
        if (field == 1) ++next.epoch;
        if (field == 2) ++next.level;
        auto rebound_host = captured;
        auto rebound_client = client;
        require(profile_bootstrap_host_bind(&rebound_host, &next));
        require(!profile_bootstrap_host_initial(&rebound_host, &context));
        require(!profile_bootstrap_host_initial(&rebound_host, &next));
        require(profile_bootstrap_client_bind(&rebound_client, &next));
        require(!profile_bootstrap_client_is_applied(&rebound_client, &context));
        require(!profile_bootstrap_client_is_applied(&rebound_client, &next));
        require(profile_bootstrap_client_should_apply(&rebound_client, &next, 0));
        require(profile_bootstrap_client_mark_applied(&rebound_client, &next));
        require(profile_bootstrap_client_is_applied(&rebound_client, &next));
    }
    auto corrupt_host = host;
    corrupt_host.initial.data[0x45] ^= 1;
    require(!profile_bootstrap_host_initial(&corrupt_host, &context));
    require(!profile_bootstrap_host_capture(&corrupt_host, &context, data, sizeof data, 0));
    corrupt_host = host;
    corrupt_host.captured = 2;
    require(!profile_bootstrap_host_initial(&corrupt_host, &context));
    require(!profile_bootstrap_host_capture(&corrupt_host, &context, data, sizeof data, 0));
    auto corrupt_client = client;
    corrupt_client.applied = 2;
    require(!profile_bootstrap_client_should_apply(&corrupt_client, &context, 0));
    require(!profile_bootstrap_client_should_apply(&corrupt_client, &context, 1));
    require(!profile_bootstrap_client_is_applied(&corrupt_client, &context));
    require(!profile_bootstrap_client_mark_applied(&corrupt_client, &context));
    auto normal_update = host.initial;
    normal_update.sequence = UINT32_MAX;
    normal_update.data[0xb57c + 21] ^= 2;
    normal_update.checksum = native_checksum(normal_update.data, sizeof normal_update.data);
    require(profile_bootstrap_profile_valid(&normal_update, &context));
    require(profile_bootstrap_client_accepts_packet(&client, &context, &normal_update, 1));
    require(!profile_bootstrap_client_should_apply(&client, &context, 0));
    require(profile_bootstrap_client_should_apply(&client, &context, 1));
    auto exchange = ProfileBootstrapClientState{};
    require(profile_bootstrap_client_bind(&exchange, &context));
    for (unsigned step = 0; step < 6; ++step) {
        const auto before = exchange;
        const bool sealed = step >= 2;
        require(profile_bootstrap_client_accepts_packet(&exchange, &context, &host.initial, sealed) == (step == 0));
        require(profile_bootstrap_client_accepts_packet(&exchange, &context, &normal_update, sealed) == (step >= 2));
        require(!std::memcmp(&before, &exchange, sizeof exchange));
        if (!step) require(profile_bootstrap_client_mark_applied(&exchange, &context));
    }
    for (unsigned field = 0; field < 5; ++field) {
        auto bad_packet = normal_update;
        if (field == 0) ++bad_packet.epoch;
        if (field == 1) ++bad_packet.level;
        if (field == 2) bad_packet.checksum ^= 1;
        if (field == 3) bad_packet.data[0] ^= 1;
        if (field == 4) bad_packet.data[0xb57c] ^= 1;
        require(!profile_bootstrap_client_accepts_packet(&exchange, &context, &bad_packet, 1));
    }
    require(!profile_bootstrap_client_accepts_packet(&exchange, &context, nullptr, 1));
    require(!profile_bootstrap_client_accepts_packet(nullptr, &context, &normal_update, 1));
    auto reconnected_context = context;
    ++reconnected_context.session;
    require(profile_bootstrap_client_bind(&exchange, &reconnected_context));
    require(!profile_bootstrap_client_accepts_packet(&exchange, &context, &host.initial, 0));
    require(!profile_bootstrap_client_accepts_packet(&exchange, &reconnected_context, &normal_update, 1));
    require(profile_bootstrap_client_accepts_packet(&exchange, &reconnected_context, &host.initial, 1));
    require(profile_bootstrap_client_mark_applied(&exchange, &reconnected_context));
    require(!profile_bootstrap_client_accepts_packet(&exchange, &reconnected_context, &host.initial, 1));
    require(profile_bootstrap_client_accepts_packet(&exchange, &reconnected_context, &normal_update, 1));
    exchange.applied = 2;
    require(!profile_bootstrap_client_accepts_packet(&exchange, &reconnected_context, &normal_update, 1));
    for (uint32_t session = 1; session <= 1000; ++session) {
        ProfileBootstrapContext next{session, 3, static_cast<int32_t>(session % 4096)};
        require(profile_bootstrap_host_bind(&host, &next));
        require(!profile_bootstrap_host_initial(&host, &next));
        require(profile_bootstrap_client_bind(&client, &next));
        require(profile_bootstrap_client_should_apply(&client, &next, 0));
        require(profile_bootstrap_host_capture(&host, &next, data, sizeof data, session));
        require(profile_bootstrap_host_initial(&host, &next)->sequence == session);
        require(profile_bootstrap_client_mark_applied(&client, &next));
        require(!profile_bootstrap_client_should_apply(&client, &next, 0));
        context = next;
    }
    profile_bootstrap_host_reset(&host);
    profile_bootstrap_client_reset(&client);
    require(!profile_bootstrap_host_initial(&host, &context));
    require(!profile_bootstrap_client_should_apply(&client, &context, 1));
    require(!profile_bootstrap_client_is_applied(&client, &context));
    require(!profile_bootstrap_client_mark_applied(&client, &context));
    require(!profile_bootstrap_host_bind(nullptr, &context));
    require(!profile_bootstrap_client_bind(nullptr, &context));
    require(!profile_bootstrap_host_capture(nullptr, &context, data, sizeof data, 0));
    require(!profile_bootstrap_client_mark_applied(nullptr, &context));
    profile_bootstrap_host_reset(nullptr);
    profile_bootstrap_client_reset(nullptr);
    std::printf("profile bootstrap: %u checks passed\n", checks);
}
