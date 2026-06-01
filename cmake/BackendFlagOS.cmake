# ==============================================================================
# FlagOS (torch_fl) Backend Configuration
# ==============================================================================
message(STATUS "Configuring FlagOS backend...")

# ------------------------------- Ascend Toolkit -------------------------------
set(ASCEND_HOME $ENV{ASCEND_TOOLKIT_HOME})
if(NOT ASCEND_HOME)
    set(ASCEND_HOME "/usr/local/Ascend/ascend-toolkit/latest")
endif()

if(NOT EXISTS ${ASCEND_HOME})
    message(FATAL_ERROR "Ascend toolkit not found at ${ASCEND_HOME}. "
                        "Please set ASCEND_TOOLKIT_HOME environment variable.")
endif()
message(STATUS "ASCEND_TOOLKIT_HOME: ${ASCEND_HOME}")

# Detect architecture
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    set(ASCEND_ARCH_DIR "aarch64-linux")
else()
    set(ASCEND_ARCH_DIR "x86_64-linux")
endif()

# ------------------------------- Find Ascend Libraries ------------------------
find_library(ASCENDCL_LIBRARY ascendcl PATHS ${ASCEND_HOME}/lib64 NO_DEFAULT_PATH REQUIRED)
find_library(ASCEND_RUNTIME_LIBRARY runtime PATHS ${ASCEND_HOME}/lib64 NO_DEFAULT_PATH REQUIRED)

message(STATUS "Found AscendCL: ${ASCENDCL_LIBRARY}")
message(STATUS "Found Ascend Runtime: ${ASCEND_RUNTIME_LIBRARY}")

# ------------------------------- Ascend Include Directories -------------------
set(ASCEND_INCLUDE_DIRS
    "${ASCEND_HOME}/include"
    "${ASCEND_HOME}/include/aclnn"
    "${ASCEND_HOME}/include/experiment"
    "${ASCEND_HOME}/include/experiment/runtime"
    "${ASCEND_HOME}/${ASCEND_ARCH_DIR}/include"
    "${ASCEND_HOME}/${ASCEND_ARCH_DIR}/include/experiment"
)

# ------------------------------- Create Imported Targets ----------------------
if(NOT TARGET Ascend::ascendcl)
    add_library(Ascend::ascendcl SHARED IMPORTED)
    set_target_properties(Ascend::ascendcl PROPERTIES
        IMPORTED_LOCATION ${ASCENDCL_LIBRARY}
        INTERFACE_INCLUDE_DIRECTORIES "${ASCEND_INCLUDE_DIRS}"
    )
endif()

if(NOT TARGET Ascend::runtime)
    add_library(Ascend::runtime SHARED IMPORTED)
    set_target_properties(Ascend::runtime PROPERTIES
        IMPORTED_LOCATION ${ASCEND_RUNTIME_LIBRARY}
        INTERFACE_INCLUDE_DIRECTORIES "${ASCEND_INCLUDE_DIRS}"
    )
endif()

# ------------------------------- torch_fl Integration -------------------------
execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import torch_fl; print(torch_fl.__path__[0])"
    OUTPUT_VARIABLE TORCH_FL_PATH OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET
)

if(TORCH_FL_PATH)
    message(STATUS "Found torch_fl at: ${TORCH_FL_PATH}")
    find_library(TORCH_FL_LIB flagos
        PATHS "${TORCH_FL_PATH}/lib"
        NO_DEFAULT_PATH
    )
    if(TORCH_FL_LIB)
        message(STATUS "Found libflagos: ${TORCH_FL_LIB}")
    else()
        message(WARNING "torch_fl package found but libflagos.so not found in ${TORCH_FL_PATH}/lib")
    endif()
else()
    message(WARNING "torch_fl not found via Python import")
endif()

# ------------------------------- Helper Function ------------------------------
function(target_link_flagos_libraries target)
    target_link_libraries(${target} PRIVATE Ascend::ascendcl Ascend::runtime)
    target_include_directories(${target} PRIVATE ${ASCEND_INCLUDE_DIRS})
    if(TORCH_FL_PATH)
        target_include_directories(${target} PRIVATE "${TORCH_FL_PATH}/include")
    endif()
    if(TORCH_FL_LIB)
        target_link_libraries(${target} PRIVATE ${TORCH_FL_LIB})
    endif()
endfunction()

message(STATUS "FlagOS backend configuration complete")
