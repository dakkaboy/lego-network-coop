#pragma once
#include <windows.h>
#include <stdint.h>
#define SPAN_SITE_COUNT 4
#define SPAN_SITE_MAX 8
typedef enum SpanInstallState {SPAN_EMPTY,SPAN_BOOTSTRAPPED,SPAN_INSTALLING,SPAN_INSTALLED,SPAN_READY,SPAN_FAILED} SpanInstallState;
typedef enum SpanInstallResult {SPAN_INSTALL_ERROR=-1,SPAN_INSTALL_DEFER=0,SPAN_INSTALL_OK=1} SpanInstallResult;
typedef struct SpanPatch {unsigned char *address;unsigned length;unsigned char original[8],replacement[8];} SpanPatch;
typedef struct SpanInstallOps {
 void *context;
 BOOL (*protect)(void*,void*,SIZE_T,DWORD,DWORD*);
 BOOL (*flush)(void*,const void*,SIZE_T);
 int (*write)(void*,void*,const void*,SIZE_T);
 int (*equal)(void*,const void*,const void*,SIZE_T);
} SpanInstallOps;
typedef struct SpanInstaller {
 volatile LONG busy,state,ready;
 void *volatile *slot;void *original_target,*owner_target;
 unsigned char *code_page;SIZE_T code_size;
 const unsigned char *forbidden;SIZE_T forbidden_size;
 SpanPatch sites[4];SpanInstallOps ops;
 DWORD main_thread;unsigned generation;
 LONG terminal;unsigned failure_phase,rollback_verified;
} SpanInstaller;
typedef struct SpanQualification {unsigned generation;DWORD thread;unsigned caller_verified,quiescent,owner_configured,main_confirmed;} SpanQualification;
int span_installer_bootstrap(SpanInstaller*,unsigned owner_configured);
int span_installer_code(SpanInstaller*,const SpanQualification*);
int span_installer_confirm(SpanInstaller*,const SpanQualification*);
