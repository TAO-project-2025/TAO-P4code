#pragma once

#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#include <tofino/bf_pal/pltfm_intf.h>
#include "hal_table_type.h"

hal_status_t hal_transaction_start(void);
hal_status_t hal_transaction_commit(void);
hal_status_t hal_transaction_abort(void);
hal_status_t hal_session_complete(void);

const char *hal_status_to_string(hal_status_t hal_status);


// -----------------------------
// route table   shc
// -----------------------------
hal_status_t hal_route_entry_add(const hal_route_key *key, const hal_route_data *data);
hal_status_t hal_route_entry_mod(const hal_route_key *key, const hal_route_data *data);
hal_status_t hal_route_entry_del(const hal_route_key *key, bool aged_flag);
hal_status_t hal_route_entry_get(const hal_route_key *key, hal_route_data *data);                                                
hal_status_t hal_route_table_usage_get(uint32_t *entry_count);
hal_status_t hal_route_table_size_get(uint32_t *size);

void hal_route_aging_ttl_balance();


void hal_init(int argc, char **argv);

#ifdef __cplusplus
}
#endif