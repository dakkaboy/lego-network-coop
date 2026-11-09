#pragma once
#ifndef ORDER_PROTECT
#define ORDER_PROTECT VirtualProtect
#define ORDER_FLUSH FlushInstructionCache
#endif
static int camera_install_call_at(unsigned char *site,const unsigned char *native,void *hook,int allowed,
 const unsigned char *prefix,size_t prefix_size) {
 if(!allowed || !site || !native || !hook || memcmp(native,prefix,prefix_size) || site[0]!=0xe8)return 0;
 int32_t displacement;memcpy(&displacement,site+1,sizeof(displacement));
 uintptr_t destination=(uintptr_t)(site+5)+(intptr_t)displacement;
 if(destination==(uintptr_t)hook)return 1;
 if(destination!=(uintptr_t)native)return 0;
 unsigned char original[5];memcpy(original,site,5);DWORD old,ignored;
 if(!ORDER_PROTECT(site,5,PAGE_EXECUTE_READWRITE,&old))return 0;
 int32_t replacement=(int32_t)((uintptr_t)hook-(uintptr_t)(site+5));memcpy(site+1,&replacement,4);
 int ok=site[0]==0xe8 && !memcmp(site+1,&replacement,4) && ORDER_FLUSH(GetCurrentProcess(),site,5);
 if(ok && ORDER_PROTECT(site,5,old,&ignored))return 1;
 memcpy(site,original,5);int flushed=ORDER_FLUSH(GetCurrentProcess(),site,5);
 int protection=ORDER_PROTECT(site,5,old,&ignored);
 return flushed && protection && !memcmp(site,original,5)?0:-1;
}
static int camera_order_install_at(unsigned char *site,const unsigned char *native,void *hook,int allowed) {
 static const unsigned char prefix[7]={0x83,0xec,0x0c,0x53,0x55,0x33,0xd2};
 return camera_install_call_at(site,native,hook,allowed,prefix,sizeof(prefix));
}
