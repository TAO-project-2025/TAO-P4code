#pragma once

#include "route.hpp"
#include "shc_digest.hpp"
#include "shc_aging.hpp"

// #include "utils/log.h"


namespace shc
{
  extern const bfrt::BfRtInfo *bfrtInfo;
  extern std::shared_ptr<bfrt::BfRtSession> session;

  extern bf_rt_target_t dev_tgt;
} // namespace shc
