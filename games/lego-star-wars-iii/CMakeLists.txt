cmake_minimum_required(VERSION 3.25)
project(CloneWarsNetworkCoop LANGUAGES C CXX ASM)

if(NOT WIN32 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "Configure from an x86 Windows development shell.")
endif()
if(NOT CMAKE_C_COMPILER_ID STREQUAL "Clang" OR NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    message(FATAL_ERROR "Use the Clang compiler drivers for the x86 hooks and assembly bridges.")
endif()

option(CLONEWARS_HIT_ENTRY_OBSERVER "Record native hit entries" OFF)
option(CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER "Record native projectile construction queries" OFF)

add_library(clonewars-camera SHARED
    src/debug/camera_init_observer.c
    src/debug/collision_observer.c
    src/debug/combat_observer.c
    src/debug/decision_observer.c
    src/debug/diagnostics.c
    src/debug/pool_birth_observer.c
    src/debug/remote_input_trace.c
    src/debug/shooter_observer.c
    src/debug/spawn_observer.c
    src/debug/user_mapping_observer.c
    src/debug/world_contact_observer.c
    src/engine/bridge.S
    src/engine/constructor_lexical_seh.c
    src/engine/context_relevance.c
    src/engine/game_state.c
    src/engine/game_state_read.c
    src/engine/game_state_read_seh.c
    src/engine/loading.c
    src/engine/model_producer_bridge.S
    src/engine/model_producer_seh.c
    src/engine/native_owner.c
    src/engine/owner_seh.c
    src/engine/rigid_body_binding.cpp
    src/engine/native_spellit_source.cpp
    src/engine/native_roster_source.cpp
    src/engine/native_hub_source.cpp
    src/engine/native_authored_poi.cpp
    src/engine/native_resource_identity.cpp
    src/engine/native_gizmo_source.cpp
    src/engine/native_script_shoot_source.cpp
    src/engine/script_shoot_dispatch_thunk.cpp
    src/engine/span_engine.c
    src/engine/span_installer.c
    src/engine/tag_lexical_seh.c
    src/engine/user_mapping_bridge.S
    src/engine/user_mapping_install.c
    src/engine/user_mapping_seh.c
    src/engine/user_mapping_session.c
    src/net/lan.c
    src/net/sync_wire.cpp
    src/render/camera.c
    src/render/camera_order_bridge.S
    src/render/camera_order_seh.c
    src/render/capture.c
    src/render/network_window.cpp
    src/render/overlay.cpp
    src/sync/cadence_journal.c
    src/sync/cadence_sync.c
    src/sync/coherent_frame_fence.c
    src/sync/entity_match.c
    src/sync/entity_sync.c
    src/sync/epoch_state.cpp
    src/sync/game_sync.c
    src/sync/geometry_journal.c
    src/sync/geometry_sync.c
    src/sync/input_buffer.cpp
    src/sync/model_input_journal.c
    src/sync/model_input_sync.c
    src/sync/npc_input.c
    src/sync/native_tick_sync.cpp
    src/sync/object_progress_sync.cpp
    src/sync/spellit_input_sync.cpp
    src/engine/native_rts_body_source.cpp
    src/sync/rts_body_input_sync.cpp
    src/sync/rts_generator_input_sync.cpp
    src/engine/native_rts_generator_source.cpp
    src/sync/rts_order_input_sync.cpp
    src/engine/native_rts_order_source.cpp
    src/engine/native_global_pack_source.cpp
    src/sync/module_rng_input_sync.cpp
    src/sync/vehicle_rng_input_sync.cpp
    src/sync/preload_state.cpp
    src/sync/profile_bootstrap_state.cpp
    src/sync/physics_input_sync.cpp
    src/sync/projectile_sync.c
    src/sync/reaction_journal.c
    src/sync/reaction_sync.c
    src/sync/spawn_timer_sync.cpp
    src/sync/tag_sync.c
    src/sync/world_vars.c
)

target_include_directories(clonewars-camera PRIVATE src ../../common)
target_compile_features(clonewars-camera PRIVATE cxx_std_23)
target_compile_options(clonewars-camera PRIVATE
    $<$<COMPILE_LANGUAGE:C,CXX>:-fms-extensions>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions;-fno-rtti>
    # The assembly bridges register no exception handlers of their own.
    $<$<COMPILE_LANGUAGE:ASM>:-Wa,-defsym,@feat.00=1>
)
target_compile_definitions(clonewars-camera PRIVATE
    COHERENT_CORE_REVIEWED_BOOTSTRAP
    CLONEWARS_REMOTE_INPUT_TRACE_DISABLED
)
if(CLONEWARS_HIT_ENTRY_OBSERVER)
    target_sources(clonewars-camera PRIVATE src/debug/hit_entry_observer.c)
    target_compile_definitions(clonewars-camera PRIVATE CLONEWARS_HIT_ENTRY_OBSERVER)
endif()
if(CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER)
    target_sources(clonewars-camera PRIVATE src/debug/constructor_observer.c src/debug/constructor_query_observer.c)
    target_compile_definitions(clonewars-camera PRIVATE CLONEWARS_CONSTRUCTOR_OBSERVER CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER CLONEWARS_COHERENT_CONSTRUCTOR_QUERY_REVIEWED)
endif()

target_link_libraries(clonewars-camera PRIVATE user32 ws2_32 shell32)

add_library(d3d9 SHARED src/engine/proxy.c src/engine/proxy.def)

option(CLONEWARS_NETWORK_TESTS "Build checks that run without the game" OFF)
if(CLONEWARS_NETWORK_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
