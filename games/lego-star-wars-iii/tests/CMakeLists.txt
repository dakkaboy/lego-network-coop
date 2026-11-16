if(CLONEWARS_ZIG_CORE)
    function(clonewars_native_zig_test unit step)
        cmake_parse_arguments(NATIVE "NO_TEST" "" "ARGS" ${ARGN})
        clonewars_zig_dependencies(sources "${CMAKE_CURRENT_SOURCE_DIR}/../src/zig/${unit}_test.zig")
        set(executable "${CMAKE_CURRENT_BINARY_DIR}/native-zig/bin/test_${unit}.exe")
        set_property(GLOBAL APPEND PROPERTY CLONEWARS_NATIVE_EXECUTABLES "${executable}")
        set_property(GLOBAL APPEND PROPERTY CLONEWARS_NATIVE_SOURCES ${sources})
        add_custom_target(test_${unit} ALL)
        add_dependencies(test_${unit} clonewars-native-suite)
        if(NOT NATIVE_NO_TEST)
            add_test(NAME clonewars-${unit} COMMAND "${executable}" ${NATIVE_ARGS})
        endif()
    endfunction()

endif()
if(CLONEWARS_ZIG_CORE)
    clonewars_native_zig_test(fixture_loader native-fixture-loader NO_TEST)
    add_subdirectory(owner)
    add_subdirectory(mapping)
    foreach(mode IN ITEMS Debug ReleaseSafe)
        set(environment_test "${CMAKE_CURRENT_BINARY_DIR}/test_environment_${mode}.exe")
        add_custom_command(OUTPUT "${environment_test}"
            COMMAND "${CLONEWARS_ZIG_EXECUTABLE}" build-exe "${CMAKE_CURRENT_SOURCE_DIR}/../src/zig/machine_environment_test.zig"
                -target x86-windows-msvc "-O${mode}" "-femit-bin=${environment_test}"
            DEPENDS ../src/zig/machine_environment_test.zig ../src/zig/machine_environment.zig VERBATIM)
        add_custom_target(clonewars-environment-${mode} ALL DEPENDS "${environment_test}")
        add_test(NAME clonewars-environment-${mode} COMMAND "${environment_test}")
    endforeach()
    set(CLONEWARS_SEH_TEST "${CMAKE_CURRENT_BINARY_DIR}/test_seh_guard.exe")
    add_custom_command(OUTPUT "${CLONEWARS_SEH_TEST}"
        COMMAND "${CLONEWARS_ZIG_EXECUTABLE}" build-exe "${CMAKE_CURRENT_SOURCE_DIR}/../src/zig/seh_guard_test.zig"
            -target x86-windows-msvc -ODebug -lc "-femit-bin=${CLONEWARS_SEH_TEST}"
        DEPENDS ../src/zig/seh_guard.zig ../src/zig/seh_guard_test.zig ../src/zig/win32.zig VERBATIM)
    add_custom_target(clonewars-seh-check ALL DEPENDS "${CLONEWARS_SEH_TEST}")
    add_test(NAME clonewars-seh_guard COMMAND "${CLONEWARS_SEH_TEST}")
    clonewars_native_zig_test(wire_abi native-wire-abi)
endif()

clonewars_native_zig_test(native_numeric native-numeric)
set_tests_properties(clonewars-native_numeric PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(input_buffer native-input-buffer)
clonewars_native_zig_test(epoch_state native-epoch-state)
clonewars_native_zig_test(lan_version native-lan-version)
clonewars_native_zig_test(lan_transport native-lan-transport)
clonewars_native_zig_test(sync_wire native-sync-wire ARGS 4)
foreach(group RANGE 0 3)
    add_test(NAME clonewars-sync_wire-${group} COMMAND "${CMAKE_CURRENT_BINARY_DIR}/native-zig/bin/test_sync_wire.exe" ${group})
endforeach()
foreach(check transition_publication)
        clonewars_zig_dependencies(publication_sources "${CMAKE_CURRENT_SOURCE_DIR}/../src/zig/lan_publication_test.zig")
        set(publication_test "${CMAKE_CURRENT_BINARY_DIR}/test_transition_publication_zig.exe")
        add_custom_command(OUTPUT "${publication_test}"
            COMMAND "${CLONEWARS_ZIG_EXECUTABLE}" build-exe "${CMAKE_CURRENT_SOURCE_DIR}/../src/zig/lan_publication_test.zig"
                -target x86-windows-msvc -OReleaseSafe -lc -fcompiler-rt "${CLONEWARS_ZIG_LIBRARY}" "-femit-bin=${publication_test}"
            DEPENDS ${publication_sources} "${CLONEWARS_ZIG_LIBRARY}" clonewars-zig-build VERBATIM)
        add_custom_target(clonewars-publication-check ALL DEPENDS "${publication_test}")
        add_executable(test_transition_publication IMPORTED)
        set_target_properties(test_transition_publication PROPERTIES IMPORTED_LOCATION "${publication_test}")
        add_dependencies(test_transition_publication clonewars-publication-check)
    add_test(NAME clonewars-${check} COMMAND test_${check})
    set_tests_properties(clonewars-${check} PROPERTIES TIMEOUT 15)
endforeach()

set_tests_properties(clonewars-lan_version clonewars-lan_transport PROPERTIES RESOURCE_LOCK clonewars-lan-test-port TIMEOUT 15)
clonewars_native_zig_test(entity_entry native-entity-entry)
set_tests_properties(clonewars-entity_entry PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(breakup_visibility native-breakup-visibility)

clonewars_native_zig_test(breakup_launch native-breakup-launch)

clonewars_native_zig_test(vehicle_rng_thunk native-vehicle-rng-thunk)

clonewars_native_zig_test(rigid_body_binding native-rigid-body-binding)

clonewars_native_zig_test(aim_task native-aim-task)

clonewars_native_zig_test(rts_competitor native-rts-competitor)

clonewars_native_zig_test(world_admission native-world-admission)

clonewars_native_zig_test(native_tick_journal native-tick-journal ARGS 0)
foreach(group RANGE 1 5)
    add_test(NAME clonewars-native_tick_journal-${group} COMMAND "${CMAKE_CURRENT_BINARY_DIR}/native-zig/bin/test_native_tick_journal.exe" ${group})
endforeach()

clonewars_native_zig_test(gizmo_source native-gizmo-source)

clonewars_native_zig_test(spellit_pose native-spellit-pose)
set_tests_properties(clonewars-spellit_pose PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(input_device_source native-input-device)
set_tests_properties(clonewars-input_device_source PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(flow_request native-flow-request)

clonewars_native_zig_test(force_target native-force-target)

clonewars_native_zig_test(aim_base native-aim-base)

clonewars_native_zig_test(force_geometry native-force-geometry)

clonewars_native_zig_test(spellit_query native-spellit-query)
set_tests_properties(clonewars-spellit_query PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(character_motion native-character-motion)

clonewars_native_zig_test(preload_state native-preload-state)
set_tests_properties(clonewars-preload_state PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(native_scene_readiness native-scene-readiness)

clonewars_native_zig_test(profile_bootstrap_state native-profile-bootstrap)
set_tests_properties(clonewars-profile_bootstrap_state PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(authored_poi native-authored-poi)

clonewars_native_zig_test(resource_identity native-resource-identity)

if(CLONEWARS_ZIG_CORE)
    clonewars_native_zig_test(camera_family native-camera-family)
    clonewars_native_zig_test(camera_graphics native-camera-graphics)
    clonewars_native_zig_test(camera_install native-camera-install)
    clonewars_native_zig_test(sync_input native-sync-input)
    clonewars_native_zig_test(sync_preload native-sync-preload)
    clonewars_native_zig_test(sync_core native-sync-core)
    clonewars_native_zig_test(sync_profiling native-sync-profiling)
    clonewars_native_zig_test(hit_entry native-hit-entry)
    clonewars_native_zig_test(constructor_observer native-constructor-observer)
    clonewars_native_zig_test(constructor_query native-constructor-query)
    clonewars_native_zig_test(projectile_constructor native-projectile-constructor)

endif()
set_tests_properties(clonewars-camera_family PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(script_shoot native-script-shoot)
set_tests_properties(clonewars-script_shoot PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(spellit_body native-spellit-body)
set_tests_properties(clonewars-spellit_body PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(projectile_pool native-projectile-pool)
set_tests_properties(clonewars-projectile_pool PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(character_support native-character-support)

clonewars_native_zig_test(reaction_receipt native-reaction-receipt)
set_tests_properties(clonewars-reaction_receipt PROPERTIES TIMEOUT 15)

clonewars_native_zig_test(spellit_completion native-spellit-completion)

clonewars_native_zig_test(rts_order native-rts-order)

clonewars_native_zig_test(rts_order_ready native-rts-order-ready)

clonewars_native_zig_test(rts_generator native-rts-generator)

clonewars_native_zig_test(rts_body native-rts-body)

if(CLONEWARS_ZIG_CORE)
    clonewars_native_zig_test(saved_sources native-saved-sources)
    clonewars_native_zig_test(spellit_source native-spellit-source)
    clonewars_native_zig_test(script_dispatch native-script-dispatch)
    clonewars_native_zig_test(span_installer native-span-installer)
    clonewars_native_zig_test(span_marker native-span-marker)
    clonewars_native_zig_test(frame_queue native-frame-queue)
    clonewars_native_zig_test(list_memory native-list-memory)
    clonewars_native_zig_test(page_access native-page-access)
    clonewars_native_zig_test(span_engine native-span-engine NO_TEST)
    foreach(scenario RANGE 0 9)
        add_test(NAME clonewars-span_engine-${scenario} COMMAND "${CMAKE_CURRENT_BINARY_DIR}/native-zig/bin/test_span_engine.exe" ${scenario})
    endforeach()
    clonewars_native_zig_test(lexical_seh native-lexical-seh)
    clonewars_native_zig_test(loading native-loading)
    clonewars_native_zig_test(proxy native-proxy ARGS "$<TARGET_FILE:d3d9-artifact>")
    add_dependencies(test_proxy d3d9)
    clonewars_native_zig_test(game_dll native-game-dll ARGS "$<TARGET_FILE:clonewars-camera-artifact>")
    add_dependencies(test_game_dll clonewars-camera)
    clonewars_native_zig_test(capture native-capture)
    clonewars_native_zig_test(game_state native-game-state)

    clonewars_native_zig_test(world_vars native-world-vars)

    clonewars_native_zig_test(npc_input native-npc-input)
    clonewars_native_zig_test(remote_trace native-remote-trace)

    clonewars_native_zig_test(diagnostics native-diagnostics)

    clonewars_native_zig_test(vehicle_rng native-vehicle-rng)

    clonewars_native_zig_test(module_rng native-module-rng)

    clonewars_native_zig_test(tick_install native-tick)
    clonewars_native_zig_test(tag_runtime native-tag)

    clonewars_native_zig_test(projectile_runtime native-projectile-runtime)

    clonewars_native_zig_test(cadence_runtime native-cadence-runtime)

    clonewars_native_zig_test(entity_runtime native-entity-runtime)

    clonewars_native_zig_test(reaction_runtime native-reaction-runtime)

    clonewars_native_zig_test(model_runtime native-model-runtime)

    clonewars_native_zig_test(spellit_input native-spellit-input)
    clonewars_native_zig_test(spellit_admission native-spellit-admission)
    clonewars_native_zig_test(spellit_admission_thunk native-spellit-admission-thunk)
    clonewars_native_zig_test(hazard_death_thunk native-hazard-death-thunk)
    clonewars_native_zig_test(tick_pack_behavior native-pack-behavior)

    clonewars_native_zig_test(spawn_observation native-spawn-observation)
    clonewars_native_zig_test(rts_dispatch_thunk native-rts-dispatch-thunk)

    clonewars_native_zig_test(combat native-combat)

    clonewars_native_zig_test(decision native-decision)

    clonewars_native_zig_test(camera_observation native-camera-observation)

    clonewars_native_zig_test(collision native-collision)

    clonewars_native_zig_test(overlay native-overlay)

    clonewars_native_zig_test(network_window native-network-window)

    clonewars_native_zig_test(shooter native-shooter)

    clonewars_native_zig_test(pool_birth native-pool-birth)

    clonewars_native_zig_test(geometry_runtime native-geometry-runtime)

    clonewars_native_zig_test(object_progress native-object-progress)

    clonewars_native_zig_test(spawn_timers native-spawn-timers)

    clonewars_native_zig_test(physics_runtime native-physics-runtime)

    clonewars_native_zig_test(mapping_session native-mapping-session NO_TEST)
    foreach(scenario RANGE 0 7)
        add_test(NAME clonewars-mapping_session-${scenario} COMMAND "${CMAKE_CURRENT_BINARY_DIR}/native-zig/bin/test_mapping_session.exe" ${scenario})
    endforeach()
endif()

if(CLONEWARS_ZIG_CORE)
    get_property(native_executables GLOBAL PROPERTY CLONEWARS_NATIVE_EXECUTABLES)
    get_property(native_sources GLOBAL PROPERTY CLONEWARS_NATIVE_SOURCES)
    list(REMOVE_DUPLICATES native_sources)
    add_custom_target(clonewars-native-suite ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/native-zig/suite.stamp")
    add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/native-zig/suite.stamp"
        BYPRODUCTS ${native_executables}
        COMMAND "${CLONEWARS_ZIG_EXECUTABLE}" build native-tests -j4 --prefix "${CMAKE_CURRENT_BINARY_DIR}/native-zig"
        COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_BINARY_DIR}/native-zig/suite.stamp"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
        DEPENDS ${native_sources} ../build.zig ../src/zig/native_tests.manifest COMMAND_EXPAND_LISTS VERBATIM)
endif()

get_property(CLONEWARS_CHECKS DIRECTORY PROPERTY TESTS)
foreach(check IN LISTS CLONEWARS_CHECKS)
    if(check MATCHES "^clonewars-(wire_abi|input_buffer|epoch_state|sync_wire(-[0-3])?|preload_state|profile_bootstrap_state|reaction_receipt)$")
        set_tests_properties(${check} PROPERTIES LABELS core TIMEOUT 15)
    elseif(check MATCHES "^clonewars-lan_(version|transport)$")
        set_tests_properties(${check} PROPERTIES LABELS network)
    else()
        set_tests_properties(${check} PROPERTIES LABELS native)
    endif()
endforeach()
