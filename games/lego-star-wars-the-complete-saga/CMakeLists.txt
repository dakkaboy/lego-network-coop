cmake_minimum_required(VERSION 3.25)
project(complete_saga LANGUAGES CXX)

if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "X86")
    message(FATAL_ERROR "Configure Complete Saga with a Win32 (x86) toolchain.")
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(d3d9 SHARED src/d3d9_proxy.cpp src/d3d9_proxy.def)
target_compile_options(d3d9 PRIVATE /W4 /WX)

include(CTest)
if(BUILD_TESTING)
    add_executable(d3d9_smoke tests/d3d9_smoke.cpp)
    target_compile_options(d3d9_smoke PRIVATE /W4 /WX)
    add_test(NAME d3d9_smoke COMMAND d3d9_smoke "$<TARGET_FILE:d3d9>")
endif()
