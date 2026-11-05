#pragma once
#include <stdint.h>
int decision_observer_install(void);
void decision_observer_invoke_actor(unsigned,void *,void (*)(void *),uint32_t);
