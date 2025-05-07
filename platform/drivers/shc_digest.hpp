#pragma once
#include <bf_rt/bf_rt.hpp>
#include <stdint.h>
#include<map>
// #include "utils/log.h"
#include "base_table.hpp"

extern "C" {
#include "hal_table_type.h"
}

namespace shc {
  struct ac_info
  {
      uint32_t pkt_num;
      uint64_t time_stamp_h;
      uint64_t time_stamp_s;
  };
  
  extern std::map<std::string,ac_info>  flows;
  extern uint32_t total_insert;
  extern uint64_t ac_count;

  extern uint32_t flow_count[6000];
  extern uint32_t time_s;

  extern uint32_t all_pkt_count[6000];
  extern uint32_t hit_ac_count[6000];

  int shc_digest_init(const bfrt::BfRtInfo *bfrtInfo, bf_rt_target_t& dev_tgt, std::shared_ptr<bfrt::BfRtSession>& session);

}

using namespace shc;