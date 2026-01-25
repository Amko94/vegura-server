cmake_minimum_required(VERSION 3.10)

set(CMAKE_DISABLE_SOURCE_CHANGES ON)
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)

project(tfs)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(cotire)

if (CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -Werror -pipe -fvisibility=hidden)
elseif (MSVC)
    add_compile_options(/W4 /WX /wd4146)
endif ()

set(CMAKE_CXX_FLAGS_PERFORMANCE "${CMAKE_CXX_FLAGS_RELEASE} -march=native")

if (CMAKE_COMPILER_IS_GNUCXX)
    add_compile_options(-fno-strict-aliasing)
endif ()

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
include(FindLTO)

# Find packages.
find_package(Crypto++ REQUIRED)
find_package(PugiXML REQUIRED)
find_package(ZLIB REQUIRED)
find_package(MySQL)
find_package(Threads)

if (LUA_FOUND)
    # Mapping der vcpkg Variablen auf die vom Projekt erwarteten Namen
    set(LUA_LIBRARIES ${LUA_LIBRARIES})
    set(LUA_INCLUDE_DIR ${LUA_INCLUDE_DIRS})
    message(STATUS "Lua found: ${LUA_INCLUDE_DIR}")
endif ()

#find_package(Boost COMPONENTS system filesystem iostreams REQUIRED)
link_directories(C:/vcpkg/installed/x64-windows/lib)

add_subdirectory(src)
add_executable(tfs ${tfs_SRC}
        src/MonsterTaskManager.cpp
        src/MonsterTaskManager.h)

include_directories(${MYSQL_INCLUDE_DIR} ${LUA_INCLUDE_DIR} ${Boost_INCLUDE_DIRS} ${PUGIXML_INCLUDE_DIR} ${Crypto++_INCLUDE_DIR})
target_link_libraries(tfs
        ${MYSQL_CLIENT_LIBS}
        lua51
        gmp
        ${Boost_LIBRARIES}
        ${PUGIXML_LIBRARIES}
        ${Crypto++_LIBRARIES}
        zlib
        ${CMAKE_THREAD_LIBS_INIT}
)

#set_target_properties(tfs PROPERTIES COTIRE_CXX_PREFIX_HEADER_INIT "src/otpch.h")
#set_target_properties(tfs PROPERTIES COTIRE_ADD_UNITY_BUILD FALSE)
#cotire(tfs)
