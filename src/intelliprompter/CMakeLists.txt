# SPDX-License-Identifier: GPL-3.0-only
# Intelliprompter additions to QPrompt. See CLAUDE.md §5.2.

option(INTELLIPROMPTER_GAMEPAD "Build gamepad support via the bundled SDL3 submodule (deferred feature)" OFF)

# Header-only for now: controller interface + pure stick-curve helper.
add_library(intelliprompter_input INTERFACE)
target_include_directories(intelliprompter_input INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_features(intelliprompter_input INTERFACE cxx_std_17)

set(INTELLIPROMPTER_SDL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../3rdparty/SDL")

if(INTELLIPROMPTER_GAMEPAD)
    if(NOT EXISTS "${INTELLIPROMPTER_SDL_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "INTELLIPROMPTER_GAMEPAD=ON but 3rdparty/SDL is missing. Run: git submodule update --init 3rdparty/SDL")
    endif()
    # Static SDL3 with only the input-related subsystems. SDL never opens a window;
    # events are pumped from a Qt timer. Video stays compiled in as a precaution
    # (Windows input backends may use SDL's helper window); try OFF when integrating.
    set(SDL_SHARED OFF CACHE BOOL "" FORCE)
    set(SDL_STATIC ON CACHE BOOL "" FORCE)
    set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
    set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
    set(SDL_TESTS OFF CACHE BOOL "" FORCE)
    set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
    foreach(_sub AUDIO GPU RENDER CAMERA POWER DIALOG TRAY)
        set(SDL_${_sub} OFF CACHE BOOL "" FORCE)
    endforeach()
    foreach(_sub VIDEO JOYSTICK HAPTIC HIDAPI SENSOR)
        set(SDL_${_sub} ON CACHE BOOL "" FORCE)
    endforeach()
    add_subdirectory("${INTELLIPROMPTER_SDL_DIR}" "${CMAKE_BINARY_DIR}/3rdparty/SDL" EXCLUDE_FROM_ALL)

    target_link_libraries(intelliprompter_input INTERFACE SDL3::SDL3-static)
    target_compile_definitions(intelliprompter_input INTERFACE INTELLIPROMPTER_GAMEPAD)
endif()
