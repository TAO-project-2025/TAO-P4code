link_directories($ENV{SDE_INSTALL}/lib/)

add_executable(driver_test
    main.cpp
    route_test.cpp
    driver_cuckoo_hash_get.cpp
)

add_dependencies(driver_test
    bfrtdriver
    # LIBFMT
)

target_link_libraries(driver_test
    bfutils
    bfsys
    driver
    bfrtdriver
    dl
    pthread
	ssl
	crypto
	thrift
	protobuf
    pcap
	# grpc
	# grpc++
	# grpc_unsecure
	# grpc++_unsecure
	# grpc_cronet
	# gpr
	event
	# grpc++_reflection
	# jsoncpp
	curl
    clish
)

target_include_directories(
    driver_test PRIVATE ${SHC_DRIVER_INCLUDE_DIR}
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE $ENV{SDE_INSTALL}/include
    # PRIVATE ${LIBFMT_INCLUDE_DIR}
    # PRIVATE ${SHC_ALARM_INCLUDE_DIR}
)

install (TARGETS driver_test DESTINATION /share_test/proj_execute)