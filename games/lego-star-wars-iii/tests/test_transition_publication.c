#undef NDEBUG
#include "../src/net/lan.c"
#include <assert.h>

int main(void) {
    generation=1;
    host_role=1;
    lan_publish_transition(1,6,1);
    assert(local_state.epoch==1 && local_state.level==6 && local_state.native_entry==1);
    lan_publish_transition(1,6,0);
    assert(local_state.native_entry==1);
    lan_publish_transition(2,7,0);
    assert(local_state.epoch==2 && local_state.level==7 && local_state.native_entry==0);
    lan_publish_transition(2,7,1);
    assert(local_state.native_entry==0);
    lan_publish_transition(3,8,2);
    assert(local_state.epoch==2 && local_state.level==7);

    struct PeerState remote={.epoch=2,.level=7,.native_entry=0};
    assert(session_peer(1,&remote));
    LanTransition accepted=lan_remote_transition();
    assert(accepted.epoch==2 && accepted.level==7 && accepted.native_entry==0);
    remote.epoch=3;remote.level=8;remote.native_entry=1;
    assert(session_peer(1,&remote));
    accepted=lan_remote_transition();
    assert(accepted.epoch==3 && accepted.level==8 && accepted.native_entry==1);
    remote.native_entry=2;
    assert(!session_peer(1,&remote));
    remote.native_entry=0;
    assert(!session_peer(2,&remote));
    accepted=lan_remote_transition();
    assert(accepted.epoch==3 && accepted.level==8 && accepted.native_entry==1);
    return 0;
}
