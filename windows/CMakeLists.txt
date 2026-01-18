# Project-level configuration.
cmake_minimum_required(VERSION 3.15) # 3.15+ provides better 'install' and generator expression support
project(ghost_signal LANGUAGES CXX)

# --- App Settings ---
set(BINARY_NAME "ghost_signal")

# Policy management: Ensure predictable behavior for modern CMake
cmake_policy(VERSION 3.15...3.27)

# --- Build Configuration ---
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
    set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release" CACHE STRING "" FORCE)
else()
    if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Flutter build mode" FORCE)
        set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Profile" "Release")
    endif()
endif()

# Inherit Release flags for the Profile mode (used by Flutter DevTools)
foreach(lang C CXX EXE_LINKER SHARED_LINKER)
    set(CMAKE_${lang}_FLAGS_PROFILE "${CMAKE_${lang}_FLAGS_RELEASE}")
endforeach()

# Unicode support is essential for modern Windows apps
add_definitions(-DUNICODE -D_UNICODE)

# --- Standard Settings Function ---
function(APPLY_STANDARD_SETTINGS TARGET)
    target_compile_features(${TARGET} PUBLIC cxx_std_17)
    
    # MSVC Specific Enhancements
    if(MSVC)
        target_compile_options(${TARGET} PRIVATE 
            /W4 /WX            # High warning level, treat as error
            /wd"4100"          # Disable unused parameter warning
            /EHsc              # Standard C++ exception handling
            /MP                # Multi-processor compilation (FASTER BUILDS)
            /permissive-       # Standards conformance mode
        )
    endif()

    target_compile_definitions(${TARGET} PRIVATE 
        "_HAS_EXCEPTIONS=0"
        "$<$<CONFIG:Debug>:_DEBUG>"
        "NOMINMAX"             # Prevents Windows headers from breaking std::min/max
    )
endfunction()

# --- Subdirectories & Dependencies ---
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})
add_subdirectory("runner")

# Include plugin rules
include(flutter/generated_plugins.cmake)

# --- Installation Logic ---

# Use generator expression to find the executable directory
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

# Install Targets & Core Files
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Plugin libraries
if(PLUGIN_BUNDLED_LIBRARIES)
    install(FILES ${PLUGIN_BUNDLED_LIBRARIES} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Native Assets (Only install if they exist to prevent build errors)
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
if(EXISTS "${NATIVE_ASSETS_DIR}")
    install(DIRECTORY "${NATIVE_ASSETS_DIR}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Clean and Refresh Flutter Assets
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")" COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}" 
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" 
        COMPONENT Runtime)

# AOT Library (Profile and Release only)
if(EXISTS "${AOT_LIBRARY}")
    install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
            CONFIGURATIONS Profile;Release COMPONENT Runtime)
endif()
