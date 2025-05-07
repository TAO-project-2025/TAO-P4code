link_directories($ENV{SDE_INSTALL}/lib/)

add_library(zdw_cntl_lib STATIC vrf.c
    tunnel_map.c
    route.c
    pmd.c
    netio.c
    neigh.c
    entry_api.c
)

set(LIBDPDK_CFLAGS 
       -include rte_config.h 
       -march=native
       -DALLOW_EXPERIMENTAL_API
)

set(LIBDPDK_LIBS 
    rte_fib
	rte_rib
	rte_hash
	rte_mbuf
	rte_mempool
	rte_rcu
	rte_ring
	rte_eal
	rte_telemetry
	rte_kvargs
	numa
)

set(LIBSTAND_LIBS
    bfutils
	bfsys
	driver
	ssl
	crypto
	pthread
	thrift
	protobuf
	# grpc
	# grpc++
	# grpc_unsecure
	# grpc++_unsecure
	# grpc_cronet
	# gpr
	dl
	event
	# grpc++_reflection
	# jsoncpp
	curl
    clish
)

target_compile_options(zdw_cntl_lib PRIVATE ${LIBDPDK_CFLAGS})

add_dependencies(zdw_cntl_lib
    # ntb_proto
    # ntb_alarm
    # ntb_collect
    # ntb_zmq
    # LIBFMT
    # CJSON
    bfrtdriver
    P4
)

target_link_libraries(zdw_cntl_lib PUBLIC
    ${LIBDPDK_LIBS}
    bfrtdriver
    driver
    # zmq
    ${LIBSTAND_LIBS}
    # ${CJSON_LIB}
    # ${LIBFMT_LIB}
)
get_property(public_private_ TARGET zdw_cntl_lib PROPERTY LINK_LIBRARIES)
message("public_private_: ${public_private_}")
# PUBLIC 后最好不要注释，否则会造成第一个${SHC_DRIVER_INCLUDE_DIR}无法识别
target_include_directories(
    zdw_cntl_lib PUBLIC 
    ${SHC_DRIVER_INCLUDE_DIR}
    # ${CJSON_INCLUDE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    $ENV{SDE_INSTALL}/include
    /usr/include/dpdk
    # ${LIBFMT_INCLUDE_DIR}
)
get_property(public_private_dirs TARGET zdw_cntl_lib PROPERTY INCLUDE_DIRECTORIES)
message("public_private_dirs: ${public_private_dirs}")

#======================== zdw_ctl ========================
add_executable(zdw_cntl main.c)

add_dependencies(zdw_cntl
    zdw_cntl_lib
)

target_link_libraries(zdw_cntl
    zdw_cntl_lib
)

# Binaries
install (TARGETS zdw_cntl DESTINATION $ENV{SDE}/install/bin/)
        #  COMPONENT cntl
        #  PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ
        #  WORLD_EXECUTE WORLD_READ)
