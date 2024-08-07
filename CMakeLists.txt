cmake_minimum_required(VERSION 3.13)
# add_link_options requires 3.13 https://cmake.org/cmake/help/v3.13/command/add_link_options.html

project(qgrep)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# for non-multi-config (not VS, Xcode, etc.), set up default build type
if ((NOT GENERATOR_IS_MULTI_CONFIG) AND (NOT CMAKE_BUILD_TYPE))
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

macro(enable_NDEBUG profile)
    string(REGEX REPLACE "([\\/\\-]D)NDEBUG" "" ${profile} "${${profile}}")
endmacro()

enable_NDEBUG(CMAKE_CXX_FLAGS_RELEASE)
enable_NDEBUG(CMAKE_CXX_FLAGS_MINSIZEREL)
enable_NDEBUG(CMAKE_CXX_FLAGS_RELWITHDEBINFO)

if (WIN32)
    add_compile_options(/DNOMINMAX /wd4996 /wd4267 /wd4244)

    if (CMAKE_SYSTEM_PROCESSOR MATCHES "(x86)|(X86)")
        add_compile_options(/DUSE_SSE2 /arch:SSE2)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm64)|(ARM64)")
        add_compile_options(-DUSE_NEON)
    else()
        message(WARNING "SIMD acceleration is disabled on ${CMAKE_SYSTEM_PROCESSOR}")
    endif()
else()
    add_compile_options(-Wall -Werror)

    if (CMAKE_SYSTEM_PROCESSOR MATCHES "(x86)|(X86)|(amd64)|(AMD64)")
        add_compile_options(-msse2 -DUSE_SSE2)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm64)|(ARM64)")
        add_compile_options(-DUSE_NEON)
    else()
        message(WARNING "SIMD acceleration is disabled on ${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
        add_compile_options(
            -mmacosx-version-min=10.7
        )
        add_link_options(
            -mmacosx-version-min=10.7
            "SHELL:-framework CoreFoundation"
            "SHELL:-framework CoreServices"
        )
    else()
        add_link_options(-Wl,--dynamic-list=${CMAKE_SOURCE_DIR}/src/qgrep.dynlist)
    endif()
endif()

if(NOT (EXISTS ${CMAKE_SOURCE_DIR}/extern/lz4/lib/lz4.c))
    message(FATAL_ERROR "run git submodule update --init to fetch lz4")
endif()

if(NOT (EXISTS ${CMAKE_SOURCE_DIR}/extern/re2/re2/re2.cc))
    message(FATAL_ERROR "run git submodule update --init to fetch re2")
endif()

add_library(re2 STATIC
    extern/re2/re2/bitmap256.cc
    extern/re2/re2/bitstate.cc
    extern/re2/re2/compile.cc
    extern/re2/re2/dfa.cc
    extern/re2/re2/filtered_re2.cc
    extern/re2/re2/mimics_pcre.cc
    extern/re2/re2/nfa.cc
    extern/re2/re2/onepass.cc
    extern/re2/re2/parse.cc
    extern/re2/re2/perl_groups.cc
    extern/re2/re2/prefilter.cc
    extern/re2/re2/prefilter_tree.cc
    extern/re2/re2/prog.cc
    extern/re2/re2/re2.cc
    extern/re2/re2/regexp.cc
    extern/re2/re2/set.cc
    extern/re2/re2/simplify.cc
    extern/re2/re2/stringpiece.cc
    extern/re2/re2/tostring.cc
    extern/re2/re2/unicode_casefold.cc
    extern/re2/re2/unicode_groups.cc
    extern/re2/util/pcre.cc
    extern/re2/util/rune.cc
    extern/re2/util/strutil.cc
)

target_include_directories(re2 PUBLIC ${CMAKE_SOURCE_DIR}/extern/re2)

add_library(lz4 STATIC
    extern/lz4/lib/lz4.c
    extern/lz4/lib/lz4hc.c
)

target_include_directories(lz4 PUBLIC ${CMAKE_SOURCE_DIR}/extern/lz4/lib)

add_executable(qgrep
    src/blockpool.cpp
    src/build.cpp
    src/changes.cpp
    src/compression.cpp
    src/encoding.cpp
    src/files.cpp
    src/filestream.cpp
    src/fileutil.cpp
    src/fileutil_posix.cpp
    src/fileutil_win.cpp
    src/filter.cpp
    src/filterutil.cpp
    src/fuzzymatch.cpp
    src/highlight.cpp
    src/highlight_win.cpp
    src/info.cpp
    src/init.cpp
    src/main.cpp
    src/orderedoutput.cpp
    src/project.cpp
    src/regex.cpp
    src/search.cpp
    src/stringutil.cpp
    src/update.cpp
    src/watch.cpp
    src/workqueue.cpp
)

target_link_libraries(qgrep PUBLIC re2 lz4)

if (NOT WIN32)
    target_link_libraries(qgrep PUBLIC pthread)
endif()

install(TARGETS qgrep DESTINATION bin)
install(
  FILES shell-completion/bash/qgrep
  DESTINATION ${CMAKE_INSTALL_DATADIR}/bash-completion/completions)
