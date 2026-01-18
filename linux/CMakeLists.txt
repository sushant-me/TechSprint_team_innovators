# Project-level configuration.
cmake_minimum_required(VERSION 3.15) # Increased for better Python/Asset handling
project(runner LANGUAGES CXX)

# --- Configuration ---
set(BINARY_NAME "ghost_signal")
set(APPLICATION_ID "com.example.ghost_signal")

# Use modern CMake policies
cmake_policy(SET CMP0063 NEW) # Visibility
cmake_policy(SET CMP0069 NEW) # LTO support

# Load bundled libraries from the lib/ directory relative to the binary.
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Profile" "Release")
endif()

# --- Functions ---

function(APPLY_STANDARD_SETTINGS TARGET)
  # 1. Modernize C++ Standard (Standard for Flutter is moving toward 17)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  
  # 2. Hardening & Warnings
  target_compile_options(${TARGET} PRIVATE 
    -Wall 
    -Wextra 
    -Wunused 
    -Wshadow
    $<$<CONFIG:Release>:-O3 -fstack-protector-strong -D_FORTIFY_SOURCE=2>
    $<$<CONFIG:Debug>:-Og -g>
  )

  # 3. Position Independent Code for security/plugins
  set_target_properties(${TARGET} PROPERTIES 
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
  )
endfunction()

# --- Dependencies ---

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# --- Build Targets ---

add_subdirectory("runner")

add_dependencies(${BINARY_NAME} flutter_assemble)

set_target_properties(${BINARY_NAME} PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)

include(flutter/generated_plugins.cmake)

# --- Installation & Bundling ---

set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Clean bundle directory (using a more efficient logic)
install(CODE "file(REMOVE_RECURSE \"${CMAKE_INSTALL_PREFIX}/\")" COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

# Install targets
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Bundled plugin libraries
if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES ${PLUGIN_BUNDLED_LIBRARIES} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Native assets
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
if(EXISTS "${NATIVE_ASSETS_DIR}")
    install(DIRECTORY "${NATIVE_ASSETS_DIR}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Flutter assets
install(DIRECTORY "${PROJECT_BUILD_DIR}/flutter_assets" 
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" 
        COMPONENT Runtime)

# AOT library for production
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  if(EXISTS "${AOT_LIBRARY}")
    install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
  endif()
endif()
