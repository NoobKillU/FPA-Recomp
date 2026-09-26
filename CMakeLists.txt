# fpa_recomp - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(fpa_recomp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(FPARECOMP_SOURCES
    src/main.cpp
)

if(WIN32)
    add_executable(fpa_recomp WIN32 ${FPARECOMP_SOURCES})
else()
    add_executable(fpa_recomp ${FPARECOMP_SOURCES})
endif()

rexglue_setup_target(fpa_recomp GPU_PLUGINS xenos)
