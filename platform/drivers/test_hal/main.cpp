#include <iostream>
#include <csignal>

extern "C" {
#include "common.h"
}

#include "test.hpp"
#include "hal.hpp"

// using ::smi::logging::logging_init;

void test_hal_status()
{
  for(int i = 0; i < HAL_STS_MAX; i++)
    printf("%s\n", hal_status_to_string(i));
}

void signalHandler(int signum) {

    freopen("/share_test/proj_output/route_output.txt","w",stdout);
    // 在信号处理函数中将数据输出到文件
    // std::cout <<"ac_count: " <<shc::ac_count << std::endl;
    std::cout <<"total_insert: " <<shc::total_insert << std::endl;
    // std::cout <<"flow num: " <<shc::flows.size() << std::endl;

    // for(uint32_t i=0;i<=shc::time_s;i++){
    //   std::cout<< shc::flow_count[i]<<std::endl;
    // }

    uint32_t entry_count;
    hal_route_table_usage_get(&entry_count);
    printf("table usage = %d\n", entry_count);
    freopen("/dev/tty", "w", stdout);

    // freopen("/share_test/proj_output/forward_num_per_sec.txt","w",stdout);
    // for(auto iter=shc::flows.begin();iter!=shc::flows.end();iter++){
    //   std::cout << iter->first <<" "<< iter->second.pkt_num <<" "<< iter->second.time_stamp_s << std::endl;
    // }
    // for(uint32_t i=0;i<=shc::time_s;i++){
    //   std::cout<<shc::all_pkt_count[i]<<" "<<shc::hit_ac_count[i]<<std::endl;
    // }

    // freopen("/dev/tty", "w", stdout);


    // freopen("/share_test/proj_output/active_flow_identification_time.txt","w",stdout);
    // for(auto iter=shc::flows.begin();iter!=shc::flows.end();iter++){
    //   std::cout << iter->first <<" "<< iter->second.time_stamp_h <<" "<< iter->second.time_stamp_s*1000 << std::endl;
    // }
    // freopen("/dev/tty", "w", stdout);
    exit(signum);
}

int main(int argc, char **argv) {
  
  signal(SIGTSTP, signalHandler); //SIGTSTP 代表 ctrl+z 终止信号

  parse_opts_and_switchd_init(argc, argv);
  // Do initial set up
  
  hal_init(argc, argv);

  index_repalce_action = true;
  aged_replace_flag = true;

  test_route(shc::session);
  // pkt_add_cuckoo();
  
  printf("\n[[[ test finished. ]]]\n");

  // return 0;
  run_cli_or_cleanup();
}
