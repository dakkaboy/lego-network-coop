add_library(clonewars-network-test-core STATIC
    ../src/net/lan.c
    ../src/net/sync_wire.cpp
    ../src/sync/preload_state.cpp
    ../src/sync/profile_bootstrap_state.cpp
    ../src/sync/epoch_state.cpp
    ../src/sync/geometry_journal.c
    ../src/sync/input_buffer.cpp
    ../src/sync/model_input_journal.c
    ../src/sync/reaction_journal.c
)
target_include_directories(clonewars-network-test-core PUBLIC ../src ../../../common)
target_compile_features(clonewars-network-test-core PRIVATE cxx_std_23)
target_compile_options(clonewars-network-test-core PRIVATE -fms-extensions)
target_compile_definitions(clonewars-network-test-core PUBLIC CLONEWARS_LAN_PORT=32521)
target_link_libraries(clonewars-network-test-core PUBLIC ws2_32)

foreach(check input_buffer epoch_state sync_wire lan_version transition_publication)
    add_executable(test_${check} test_${check}.c)
    target_link_libraries(test_${check} PRIVATE clonewars-network-test-core)
    add_test(NAME clonewars-${check} COMMAND test_${check})
    set_tests_properties(clonewars-${check} PROPERTIES TIMEOUT 15)
endforeach()

add_executable(test_entity_entry test_entity_entry.c ../src/sync/entity_sync.c ../src/sync/entity_match.c)
target_include_directories(test_entity_entry PRIVATE ../src)
target_compile_definitions(test_entity_entry PRIVATE ENTITY_SYNC_TEST ENTITY_SYNC_API=)
target_compile_options(test_entity_entry PRIVATE -fms-extensions)
add_test(NAME clonewars-entity_entry COMMAND test_entity_entry)
set_tests_properties(clonewars-entity_entry PROPERTIES TIMEOUT 15)

add_executable(test_breakup_visibility test_breakup_visibility.cpp)
target_compile_features(test_breakup_visibility PRIVATE cxx_std_23)
target_compile_options(test_breakup_visibility PRIVATE -fms-extensions)
add_test(NAME clonewars-breakup_visibility COMMAND test_breakup_visibility)
set_tests_properties(clonewars-breakup_visibility PROPERTIES TIMEOUT 15)

add_executable(test_breakup_launch test_breakup_launch.cpp)
target_compile_features(test_breakup_launch PRIVATE cxx_std_23)
target_compile_options(test_breakup_launch PRIVATE -fms-extensions)
add_test(NAME clonewars-breakup_launch COMMAND test_breakup_launch)
set_tests_properties(clonewars-breakup_launch PROPERTIES TIMEOUT 15)

add_executable(test_rigid_body_binding test_rigid_body_binding.cpp ../src/engine/rigid_body_binding.cpp)
target_compile_features(test_rigid_body_binding PRIVATE cxx_std_23)
target_compile_options(test_rigid_body_binding PRIVATE -fms-extensions)
add_test(NAME clonewars-rigid_body_binding COMMAND test_rigid_body_binding)
set_tests_properties(clonewars-rigid_body_binding PROPERTIES TIMEOUT 15)

add_executable(test_aim_task test_aim_task.cpp)
target_compile_features(test_aim_task PRIVATE cxx_std_23)
target_compile_options(test_aim_task PRIVATE -fms-extensions)
add_test(NAME clonewars-aim_task COMMAND test_aim_task)
set_tests_properties(clonewars-aim_task PROPERTIES TIMEOUT 15)

add_executable(test_rts_competitor test_rts_competitor.cpp)
target_compile_features(test_rts_competitor PRIVATE cxx_std_23)
target_compile_options(test_rts_competitor PRIVATE -fms-extensions)
add_test(NAME clonewars-rts_competitor COMMAND test_rts_competitor)
set_tests_properties(clonewars-rts_competitor PROPERTIES TIMEOUT 15)

add_executable(test_native_world_admission test_native_world_admission.cpp)
target_compile_features(test_native_world_admission PRIVATE cxx_std_23)
target_compile_options(test_native_world_admission PRIVATE -fms-extensions)
add_test(NAME clonewars-native_world_admission COMMAND test_native_world_admission)
set_tests_properties(clonewars-native_world_admission PROPERTIES TIMEOUT 15)

add_executable(test_native_tick_journal test_native_tick_journal.cpp ../src/sync/native_tick_sync.cpp)
target_compile_features(test_native_tick_journal PRIVATE cxx_std_23)
target_compile_options(test_native_tick_journal PRIVATE -fms-extensions)
add_test(NAME clonewars-native_tick_journal COMMAND test_native_tick_journal)
target_link_options(test_native_tick_journal PRIVATE "SHELL:-Xlinker /dynamicbase:no" "SHELL:-Xlinker /base:0x400000")
set_tests_properties(clonewars-native_tick_journal PROPERTIES TIMEOUT 15)

add_executable(test_input_device_source test_input_device_source.cpp)
target_compile_features(test_input_device_source PRIVATE cxx_std_23)
add_test(NAME clonewars-input_device_source COMMAND test_input_device_source)
set_tests_properties(clonewars-input_device_source PROPERTIES TIMEOUT 15)

add_executable(test_native_flow_request test_native_flow_request.cpp)
target_compile_features(test_native_flow_request PRIVATE cxx_std_23)
target_compile_options(test_native_flow_request PRIVATE -fms-extensions)
add_test(NAME clonewars-native_flow_request COMMAND test_native_flow_request)
set_tests_properties(clonewars-native_flow_request PROPERTIES TIMEOUT 15)

add_executable(test_force_target test_force_target.cpp)
target_compile_features(test_force_target PRIVATE cxx_std_23)
target_compile_options(test_force_target PRIVATE -fms-extensions)
add_test(NAME clonewars-force_target COMMAND test_force_target)
set_tests_properties(clonewars-force_target PROPERTIES TIMEOUT 15)

add_executable(test_aim_base test_aim_base.cpp)
target_compile_features(test_aim_base PRIVATE cxx_std_23)
target_compile_options(test_aim_base PRIVATE -fms-extensions)
add_test(NAME clonewars-aim_base COMMAND test_aim_base)
set_tests_properties(clonewars-aim_base PROPERTIES TIMEOUT 15)

add_executable(test_force_geometry test_force_geometry.cpp)
target_compile_features(test_force_geometry PRIVATE cxx_std_23)
target_compile_options(test_force_geometry PRIVATE -fms-extensions)
add_test(NAME clonewars-force_geometry COMMAND test_force_geometry)
set_tests_properties(clonewars-force_geometry PROPERTIES TIMEOUT 15)

add_executable(test_spellit_query test_spellit_query.cpp)
target_compile_features(test_spellit_query PRIVATE cxx_std_23)
target_compile_options(test_spellit_query PRIVATE -fms-extensions)
add_test(NAME clonewars-spellit_query COMMAND test_spellit_query)
set_tests_properties(clonewars-spellit_query PROPERTIES TIMEOUT 15)

add_executable(test_character_motion test_character_motion.cpp)
target_compile_features(test_character_motion PRIVATE cxx_std_23)
target_compile_options(test_character_motion PRIVATE -fms-extensions)
add_test(NAME clonewars-character_motion COMMAND test_character_motion)
set_tests_properties(clonewars-character_motion PROPERTIES TIMEOUT 15)

add_executable(test_preload_state test_preload_state.cpp ../src/sync/preload_state.cpp)
target_compile_features(test_preload_state PRIVATE cxx_std_23)
add_test(NAME clonewars-preload_state COMMAND test_preload_state)
set_tests_properties(clonewars-preload_state PROPERTIES TIMEOUT 15)

add_executable(test_native_scene_readiness test_native_scene_readiness.cpp)
target_compile_features(test_native_scene_readiness PRIVATE cxx_std_23)
target_compile_options(test_native_scene_readiness PRIVATE -fms-extensions)
add_test(NAME clonewars-native_scene_readiness COMMAND test_native_scene_readiness)
set_tests_properties(clonewars-native_scene_readiness PROPERTIES TIMEOUT 15)

add_executable(test_profile_bootstrap_state test_profile_bootstrap_state.cpp)
target_compile_features(test_profile_bootstrap_state PRIVATE cxx_std_23)
target_link_libraries(test_profile_bootstrap_state PRIVATE clonewars-network-test-core)
add_test(NAME clonewars-profile_bootstrap_state COMMAND test_profile_bootstrap_state)
set_tests_properties(clonewars-profile_bootstrap_state PROPERTIES TIMEOUT 15)

add_executable(test_native_authored_poi test_native_authored_poi.cpp ../src/engine/native_authored_poi.cpp)
target_include_directories(test_native_authored_poi PRIVATE ../src)
target_compile_features(test_native_authored_poi PRIVATE cxx_std_23)
target_compile_options(test_native_authored_poi PRIVATE -fms-extensions)
add_test(NAME clonewars-native_authored_poi COMMAND test_native_authored_poi)
set_tests_properties(clonewars-native_authored_poi PROPERTIES TIMEOUT 15)

add_executable(test_native_resource_identity test_native_resource_identity.cpp ../src/engine/native_resource_identity.cpp)
target_include_directories(test_native_resource_identity PRIVATE ../src)
target_compile_features(test_native_resource_identity PRIVATE cxx_std_23)
target_compile_options(test_native_resource_identity PRIVATE -fms-extensions)
target_link_options(test_native_resource_identity PRIVATE "SHELL:-Xlinker /dynamicbase:no" "SHELL:-Xlinker /base:0x400000")
add_test(NAME clonewars-native_resource_identity COMMAND test_native_resource_identity)
set_tests_properties(clonewars-native_resource_identity PROPERTIES TIMEOUT 15)

add_executable(test_camera_family test_camera_family.c)
target_include_directories(test_camera_family PRIVATE ../src)
target_compile_options(test_camera_family PRIVATE -fms-extensions)
target_link_options(test_camera_family PRIVATE "SHELL:-Xlinker /dynamicbase:no" "SHELL:-Xlinker /base:0x400000")
add_test(NAME clonewars-camera_family COMMAND test_camera_family)
set_tests_properties(clonewars-camera_family PROPERTIES TIMEOUT 15)

add_executable(test_native_script_shoot test_native_script_shoot.cpp ../src/engine/native_script_shoot_source.cpp)
target_include_directories(test_native_script_shoot PRIVATE ../src)
target_compile_features(test_native_script_shoot PRIVATE cxx_std_23)
target_compile_options(test_native_script_shoot PRIVATE -fms-extensions)
target_link_options(test_native_script_shoot PRIVATE "SHELL:-Xlinker /dynamicbase:no" "SHELL:-Xlinker /base:0x400000")
add_test(NAME clonewars-native_script_shoot COMMAND test_native_script_shoot)
set_tests_properties(clonewars-native_script_shoot PROPERTIES TIMEOUT 15)
