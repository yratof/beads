cmake_minimum_required(VERSION 3.10)
project(beads LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wno-vla-extension)
endif()

add_compile_options(
  -Wall
  -Wno-unused-function
  -Wno-sign-compare
  -Wno-unused-variable
  -fno-strict-aliasing
)

include_directories(${CMAKE_SOURCE_DIR}/vendor ${CMAKE_SOURCE_DIR}/src)

file(GLOB BEADS_DSP_SRC
  vendor/beads/dsp/*.cc
  vendor/beads/resources.cc
  vendor/stmlib/dsp/*.cc
  vendor/stmlib/utils/*.cc
)

add_library(beads_dsp STATIC ${BEADS_DSP_SRC} src/BeadsEngine.cpp)
set_target_properties(beads_dsp PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_compile_options(beads_dsp PRIVATE -O2)

add_executable(beads_render src/render_test.cpp)
target_link_libraries(beads_render PRIVATE beads_dsp)
target_compile_options(beads_render PRIVATE -O2)

if(SC_PATH)
  if(EXISTS ${SC_PATH}/include/plugin_interface/SC_PlugIn.h)
    set(SC_INCLUDE ${SC_PATH}/include)
  elseif(EXISTS ${SC_PATH}/plugin_interface/SC_PlugIn.h)
    set(SC_INCLUDE ${SC_PATH})
  else()
    message(FATAL_ERROR "Could not find SC_PlugIn.h under SC_PATH=${SC_PATH}")
  endif()

  add_library(Beads MODULE src/Beads.cpp)
  target_include_directories(Beads PRIVATE ${SC_INCLUDE}/plugin_interface ${SC_INCLUDE}/common)
  target_link_libraries(Beads PRIVATE beads_dsp)
  target_compile_options(Beads PRIVATE -O2)
  set_target_properties(Beads PROPERTIES PREFIX "" OUTPUT_NAME "Beads")
  if(APPLE)
    set_target_properties(Beads PROPERTIES SUFFIX ".scx")
    target_link_options(Beads PRIVATE -undefined dynamic_lookup)
  else()
    set_target_properties(Beads PROPERTIES SUFFIX ".so")
    target_link_options(Beads PRIVATE -shared)
  endif()
endif()
