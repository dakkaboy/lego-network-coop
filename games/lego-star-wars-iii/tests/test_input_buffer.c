#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include "sync/input_buffer.h"

int main(void) {
    InputBuffer buffer;
    input_buffer_reset(&buffer);
    SyncInput press={.held=0x8000,.pressed=0x8000,.analog_x=128,.analog_y=128,.aim_x=128,.aim_y=128};
    SyncInput release={0,0,128,128,128,128};
    input_buffer_sample(&buffer,&press);
    for (int wait=0;wait<8;++wait) input_buffer_sample(&buffer,&release);
    SyncInput delivered=input_buffer_take(&buffer);
    assert(delivered.held==0 && delivered.pressed==0x8000);
    assert(delivered.analog_x==128 && delivered.aim_y==128);
    assert(input_buffer_take(&buffer).pressed==0);

    input_buffer_sample(&buffer,&press);
    SyncInput jump={.held=0x4000,.pressed=0x4000,.analog_x=230,.analog_y=128,.aim_x=11,.aim_y=219};
    input_buffer_sample(&buffer,&jump);
    delivered=input_buffer_take(&buffer);
    assert(delivered.pressed==0xc000 && delivered.held==0x4000);
    assert(delivered.analog_x==230 && delivered.aim_x==11 && delivered.aim_y==219);
    assert(input_buffer_take(&buffer).pressed==0);

    input_buffer_sample(&buffer,&press);
    input_buffer_reset(&buffer);
    delivered=input_buffer_take(&buffer);
    assert(!delivered.held && !delivered.pressed && delivered.analog_x==128);
    puts("Input wait: press+release entirely within ack wait survives once; combined edges/latest axes and epoch reset passed");
}
