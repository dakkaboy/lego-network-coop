add_library(clonewars-network-test-core STATIC
    ../src/net/lan.c
    ../src/net/sync_wire.cpp
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

foreach(check input_buffer epoch_state sync_wire lan_version)
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
