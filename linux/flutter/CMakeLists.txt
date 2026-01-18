# This file controls Flutter-level build steps.
# Optimized for performance and CMake 3.15+ compatibility.
cmake_minimum_required(VERSION 3.15)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# === Flutter Library & Dependencies ===

find_package(PkgConfig REQUIRED)
# Grouped modules check for slightly faster configuration
pkg_check_modules(FLUTTER_DEPS REQUIRED IMPORTED_TARGET 
    gtk+-3.0 
    glib-2.0 
    gio-2.0
)

set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/libflutter_linux_gtk.so")

# Export variables to parent scope for installation
set(FLUTTER_LIBRARY "${FLUTTER_LIBRARY}" PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_DIR}/build/lib/libapp.so" PARENT_SCOPE)

# Define headers using a more maintainable list
set(FLUTTER_LIBRARY_HEADERS
    "fl_basic_message_channel.h"
    "fl_binary_codec.h"
    "fl_binary_messenger.h"
    "fl_dart_project.h"
    "fl_engine.h"
    "fl_json_message_codec.h"
    "fl_json_method_codec.h"
    "fl_message_codec.h"
    "fl_method_call.h"
    "fl_method_channel.h"
    "fl_method_codec.h"
    "fl_method_response.h"
    "fl_plugin_registrar.h"
    "fl_plugin_registry.h"
    "fl_standard_message_codec.h"
    "fl_standard_method_codec.h"
    "fl_string_codec.h"
    "fl_value.h"
    "fl_view.h"
    "flutter_linux.h"
)

# Use built-in list(TRANSFORM) available in CMake 3.12+ 
# This replaces the custom list_prepend function.
list(TRANSFORM FLUTTER_LIBRARY_HEADERS PREPEND "${EPHEMERAL_DIR}/flutter_linux/")

# Create the Flutter interface library
add_library(flutter INTERFACE)

target_include_directories(flutter INTERFACE
    "${EPHEMERAL_DIR}"
)

# Link against the .so and the discovered PkgConfig modules
target_link_libraries(flutter INTERFACE 
    "${FLUTTER_LIBRARY}"
    PkgConfig::FLUTTER_DEPS
)

# Link the assembly dependency to the library
add_dependencies(flutter flutter_assemble)

# === Flutter Tool Backend (Build Logic) ===

# Using a symbolic name for the phony target for better readability
set(PHONY_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/flutter_assemble.phony")

add_custom_command(
    OUTPUT 
        "${FLUTTER_LIBRARY}" 
        ${FLUTTER_LIBRARY_HEADERS}
        "${PHONY_OUTPUT}"
    COMMAND ${CMAKE_COMMAND} -E env
        ${FLUTTER_TOOL_ENVIRONMENT}
        "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.sh"
        ${FLUTTER_TARGET_PLATFORM} ${CMAKE_BUILD_TYPE}
    COMMENT "Building Flutter engine and assembling assets..."
    VERBATIM
)

add_custom_target(flutter_assemble DEPENDS
    "${FLUTTER_LIBRARY}"
    ${FLUTTER_LIBRARY_HEADERS}
    "${PHONY_OUTPUT}"
)
