#include "hal.hpp"
#include "hal_table_api.h"

namespace shc {
  
const bfrt::BfRtInfo *bfrtInfo = nullptr;
std::shared_ptr<bfrt::BfRtSession> session;

#define ALL_PIPES 0xffff
bf_rt_target_t dev_tgt;

void setUp() {
  dev_tgt.dev_id = 0;
  dev_tgt.pipe_id = ALL_PIPES;
  dev_tgt.direction = BF_DEV_DIR_ALL;
  dev_tgt.prsr_id = 0xff;
  // Get devMgr singleton instance
  auto &devMgr = bfrt::BfRtDevMgr::getInstance();

  // Get bfrtInfo object from dev_id and p4 program name
  auto bf_status =
      devMgr.bfRtInfoGet(dev_tgt.dev_id, "shc_real_time_sketch", &bfrtInfo);
  // Check for status
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Create a session object
  session = bfrt::BfRtSession::sessionCreate();
}

}// end namespace shc 

using namespace shc;

void hal_init(int argc, char **argv) {
  // Do initial set up
  shc::setUp();
  
  // TODO:先设置为DEBUG,之后修改为INFO
  // auto  status = logging_init(HAL_API_LEVEL_DEBUG);
  // if (status != HAL_STATUS_SUCCESS) {
  //     printf("init log failed!!!");
  // }

  // HAL_LOG_INFO(LOG_USER1, "HAL SetUp Finish. Session Handle: {}, PRE Session Handle: {}", 
  //                           session->sessHandleGet(), session->preSessHandleGet());


  shc::route_init(bfrtInfo, dev_tgt, session);

  shc::shc_digest_init(bfrtInfo, dev_tgt, session);
  shc::shc_aging_init(bfrtInfo, dev_tgt, session);


  /* 表项根据index直接替换。基于sde中定义的参数yxj_aged_flag */
  direct_replace = false; // 控制是否根据index直接替换
  yxj_entry_index = 0; // 直接替换的index

  /* 统计流表可用率的参数 */
  entry_in_table_c = 0;
  entry_aged_c = 0;
  aged_replace = false; // 控制是否启用aged replace
  aged_replace_flag = false; // 控制是否复用aged机制

  /* 变相实现流表与sketch耦合的参数 */
  index_repalce_action = false;

  cuckoo_hash_get_flag = false;
  driver_cuckoo_hash_get[0] = 0;
  driver_cuckoo_hash_get[1] = 0;
  driver_cuckoo_hash_get[2] = 0;
  driver_cuckoo_hash_get[3] = 0;
  driver_cuckoo_hash_get[4] = 0;

}

