#include "hal_table_api.h"
#include "hal_utils.hpp"
#include "hal.hpp"


const char *hal_status_to_string(hal_status_t hal_status) {
  if (hal_status < 0)
    hal_status = ~hal_status;
  return hal_err_str(hal_status);
}


// -----------------------------
// route table   shc
// -----------------------------
hal_status_t hal_route_entry_add(const hal_route_key *key,
                            const hal_route_data *data){
  shc::route_table->tableMutexLock();
  auto status = shc::route_table->tableEntryAddModify(key, data, true); 
  shc::route_table->tableMutexUnlock();
  return status;                           
}
hal_status_t hal_route_entry_mod(const hal_route_key *key,
                            const hal_route_data *data){
  shc::route_table->tableMutexLock();
  auto status = shc::route_table->tableEntryAddModify(key, data, false);  
  shc::route_table->tableMutexUnlock(); 
  return status;                                                     
}
hal_status_t hal_route_entry_del(const hal_route_key *key, bool aged_flag){
  shc::route_table->tableMutexLock();
  auto status = shc::route_table->tableEntryDel(key, aged_flag);
  shc::route_table->tableMutexUnlock();
  return status;                           
}
hal_status_t hal_route_entry_get(const hal_route_key *key, hal_route_data *data){
  shc::route_table->tableMutexLock();
  auto status = shc::route_table->tableEntryGet(key, data);
  shc::route_table->tableMutexUnlock();
  return status;                           
}                                                  
hal_status_t hal_route_table_usage_get(uint32_t *entry_count){
  shc::route_table->tableMutexLock();
  auto status = shc::route_table->tableUsageGet(entry_count);
  shc::route_table->tableMutexUnlock();
  return status;                           
}
hal_status_t hal_route_table_size_get(uint32_t *size){
  shc::route_table->tableMutexLock();
  auto status = shc::route_table->tableSizeGet(size);
  shc::route_table->tableMutexUnlock();
  return status;                           
}
void hal_route_aging_ttl_balance(){
  shc::route_table->tableMutexLock();
    // printf("========== new round ==========\n");
    shc::route_table->aging_ttl_balance();
    // printf("========== round end ==========\n\n");
  shc::route_table->tableMutexUnlock();
  return ;   
}

