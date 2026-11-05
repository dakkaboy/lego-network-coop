#pragma once
#include "user_mapping_observer.h"
typedef struct UserMappingInstallConfig {uint32_t main_thread;UserMappingSourceValid original_source_valid;int (__cdecl *install_allowed)(void *);void *user;} UserMappingInstallConfig;
int user_mapping_install_safe(const UserMappingInstallConfig *);
int user_mapping_install_ready(void);
