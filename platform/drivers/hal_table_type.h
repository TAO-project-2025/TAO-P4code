#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "hal_types.h"


//-------route and route_sele-------//
typedef struct {
  // uint32_t vrf;
  uint32_t ip_src_addr;
  uint32_t ip_dst_addr;
} hal_route_key;

typedef struct {
  uint32_t nhop_id;
} hal_route_data;


/* 从驱动接出来的变量 */

extern bool direct_replace; //yxj add
extern uint32_t yxj_entry_index; //yxj add

extern uint32_t entry_in_table_c; //yxj add
extern uint32_t entry_aged_c; //yxj add
extern bool aged_replace; //yxj add
extern bool aged_replace_flag; //yxj add

extern bool index_repalce_action; //yxj add

extern uint32_t driver_cuckoo_hash_get[5]; //yxj add
extern bool cuckoo_hash_get_flag; //yxj add

#ifdef __cplusplus
}
#endif