#include "equipment_oracle.h"
#include <string.h>

static int get(EquipmentRead read,void *context,uint32_t base,uint32_t offset,
               void *out,size_t size,EquipmentReason *reason) {
    if(!base || offset>UINT32_MAX-base || size>UINT32_MAX-(base+offset)+1ULL){
        *reason=EQUIPMENT_ADDRESS_OVERFLOW;return 0;
    }
    if(!read(context,base+offset,out,size)){*reason=EQUIPMENT_UNREADABLE;return 0;}
    return 1;
}
EquipmentOracle equipment_oracle(EquipmentRead read,void *context,uint32_t actor,
                                 const uint32_t cached_all[4],const uint32_t cached_active[4]) {
    EquipmentOracle out={0};uint32_t node,held,seen[EQUIPMENT_ORACLE_LIMIT];
    if(!read || !actor){out.reason=EQUIPMENT_BAD_ARGUMENT;return out;}
    if(!get(read,context,actor,0x520,&node,4,&out.reason) ||
       !get(read,context,actor,0x528,&held,4,&out.reason))goto unknown;
    while(node){
        for(uint32_t i=0;i<out.node_count;++i)if(seen[i]==node){out.reason=EQUIPMENT_CYCLE;goto unknown;}
        if(out.node_count==EQUIPMENT_ORACLE_LIMIT){out.reason=EQUIPMENT_TRUNCATED;goto unknown;}
        uint32_t next,object,definition,flags[4];uint8_t type;
        seen[out.node_count++]=node;
        if(!get(read,context,node,0,&next,4,&out.reason) ||
           !get(read,context,node,0x48,&type,1,&out.reason))goto unknown;
        if(node==held)out.held_member=1;
        if(type!=4){
            if(!get(read,context,node,8,&object,4,&out.reason) ||
               !get(read,context,object,0xac,&definition,4,&out.reason) ||
               !get(read,context,definition,0x38,flags,sizeof(flags),&out.reason))goto unknown;
            for(unsigned i=0;i<4;++i)out.all_flags[i]|=flags[i];
            if(type==3){++out.type3_count;for(unsigned i=0;i<4;++i)out.active_flags[i]|=flags[i];}
        }
        node=next;
    }
    out.status=EQUIPMENT_COMPLETE;
    if(cached_all && cached_active){
        out.cache_comparison_known=1;
        out.cache_matches=!memcmp(cached_all,out.all_flags,sizeof(out.all_flags)) &&
                          !memcmp(cached_active,out.active_flags,sizeof(out.active_flags));
    }
    return out;
unknown:
    {EquipmentReason reason=out.reason;memset(&out,0,sizeof(out));out.reason=reason;return out;}
}
