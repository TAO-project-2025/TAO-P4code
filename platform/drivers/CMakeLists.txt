project(shcdriver)

add_library(bfrtdriver STATIC
    base_table.cpp
    # hal_common_api.cpp
    hal_init.cpp
    hal_table_api.cpp

    route.cpp

    shc_digest.cpp
    shc_aging.cpp
    
    # utils/log.cpp
    # utils/object_id.cpp
)

# target_link_libraries(bfrtdriver ${LIBFMT_LIB})
target_include_directories(bfrtdriver #PUBLIC ${LIBFMT_INCLUDE_DIR}
                                      PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
                                      PRIVATE $ENV{SDE_INSTALL}/include)

set(SHC_DRIVER_INCLUDE_DIR  ${CMAKE_CURRENT_SOURCE_DIR} CACHE STRING INTERNAL)

add_subdirectory(test_hal)