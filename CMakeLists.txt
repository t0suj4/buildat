# http://www.apache.org/licenses/LICENSE-2.0
# Copyright 2014 Perttu Ahola <celeron55@gmail.com>

cmake_minimum_required(VERSION 2.6)
project(buildat)

#
# Bundled libraries
#

add_subdirectory("3rdparty/cereal")
add_subdirectory("3rdparty/c55lib")
add_subdirectory("3rdparty/smallsha1")

include_directories("src")
include_directories("3rdparty/cereal/include")
include_directories("3rdparty/c55lib")
include_directories("3rdparty/smallsha1")

#
# Global options
#

set(BUILD_GUARD  TRUE CACHE BOOL "Build LD_PRELOAD guard (used for the client)")
set(BUILD_SERVER TRUE CACHE BOOL "Build server")
set(BUILD_CLIENT TRUE CACHE BOOL "Build client")

#
# Urho3D dependency
#

set(URHO3D_HOME $ENV{URHO3D_HOME})
message(STATUS "URHO3D_HOME=\"${URHO3D_HOME}\"")
if("${URHO3D_HOME}" STREQUAL "")
	message(FATAL_ERROR "You need to set the URHO3D_HOME environment variable.")
endif()

set(CMAKE_MODULE_PATH ${URHO3D_HOME}/Source/CMake/Modules PATH "Path to Urho3D-specific CMake modules")
include(Urho3D-CMake-common)
find_package(Urho3D REQUIRED)
include_directories(${URHO3D_INCLUDE_DIRS})

# Urho3D's Lua
include_directories(${URHO3D_HOME}/Source/ThirdParty/Lua/src)

# Run some automagic from Urho3D.
# This appends to at least ${ABSOLUTE_PATH_LIBS} and {LINK_LIBS_ONLY}
define_dependency_libs("Urho3D")

#
# Buildat
#

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x -Wall")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wextra -Wno-unused-parameter")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -std=c++0x -g -O0 -Wall")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin") # Executables
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib") # Shared libs
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib") # Static libs

# Always output in color (useful when using head for build output)
#set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fdiagnostics-color=always")
# Security / crash protection
#set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fstack-protector-all")

set(CLIENT_EXE_NAME buildat_client)
set(SERVER_EXE_NAME buildat_server)

if(BUILD_GUARD)
	# LD_PRELOAD wrapper
	set(PRELOAD_LIB_NAME buildat_guard)
	set(PRELOAD_SRCS
		src/guard/lib.c
	)
	add_library(${PRELOAD_LIB_NAME} SHARED ${PRELOAD_SRCS})

	# Create wrapper script in place of client
	set(GUARD_SCRIPT_NAME ${CLIENT_EXE_NAME})
	set(GUARD_SCRIPT_PATH ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${GUARD_SCRIPT_NAME})
	add_custom_command(
		OUTPUT ${GUARD_SCRIPT_PATH}
		COMMAND cp ${CMAKE_SOURCE_DIR}/src/guard/guard_launcher.sh
				${GUARD_SCRIPT_PATH}
		COMMAND chmod +x ${GUARD_SCRIPT_PATH}
		DEPENDS ${CMAKE_SOURCE_DIR}/src/guard/guard_launcher.sh
		VERBATIM
	)
	add_custom_target(generate_guard_script ALL
		DEPENDS ${GUARD_SCRIPT_PATH}
		DEPENDS ${CMAKE_SOURCE_DIR}/src/guard/guard_launcher.sh)

	# Rename client to different name
	set(CLIENT_EXE_NAME "${CLIENT_EXE_NAME}.bin")
endif(BUILD_GUARD)

if(BUILD_CLIENT)
	# Client
	set(CLIENT_SRCS
		src/guard/buildat_guard_interface.cpp
		src/client/main.cpp
		src/client/state.cpp
		src/client/app.cpp
		src/client/config.cpp
		src/core/log.cpp
		src/impl/fs.cpp
		src/impl/tcpsocket.cpp
		src/impl/sha1.cpp
		src/impl/packet_stream.cpp
	)

	add_executable(${CLIENT_EXE_NAME} ${CLIENT_SRCS})

	target_link_libraries(${CLIENT_EXE_NAME}
		c55lib
		smallsha1
		${ABSOLUTE_PATH_LIBS}
		${LINK_LIBS_ONLY}
	)
endif(BUILD_CLIENT)

if(BUILD_SERVER)
	# Server
	set(SERVER_SRCS
		src/server/main.cpp
		src/server/state.cpp
		src/server/rccpp.cpp
		src/server/config.cpp
		src/core/log.cpp
		src/impl/fs.cpp
		src/impl/event.cpp
		src/impl/tcpsocket.cpp
		src/impl/module.cpp
		src/impl/linux/file_watch.cpp
		src/impl/linux/process.cpp
		src/impl/sha1.cpp
		src/impl/packet_stream.cpp
	)
	add_executable(${SERVER_EXE_NAME} ${SERVER_SRCS})

	target_link_libraries(${SERVER_EXE_NAME}
		c55lib
		smallsha1
		dl
		${ABSOLUTE_PATH_LIBS}
		${LINK_LIBS_ONLY}
	)
endif(BUILD_SERVER)

# vim: set noet ts=4 sw=4:
