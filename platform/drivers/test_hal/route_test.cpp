#include "test.hpp"


void flow_table_rate_test(){
  uint32_t src_ip,dst_ip;
  hal_route_key key5;
  hal_route_data data5 = {.nhop_id=0};
  clock_t start,end,time_record=0;
  uint32_t status,su=0;

  // std::ofstream ratecout("/share_test/proj_output/offload_rate.txt",std::ios::app); // 不会自己创建文件夹

  // _rdrand64_step(&ipx);
  // _rdrand32_step(&src_ip);
  // _rdrand32_step(&dst_ip);
  srand(time(0));
  start = clock();
  // aged_replace = true;
  while(1){
    src_ip = (uint32_t)rand();
    dst_ip = (uint32_t)rand();
    key5.ip_src_addr = src_ip;
    key5.ip_dst_addr = dst_ip;

    // std::cout<<"========== new round insert =========="<<std::endl;
    // std::cout<<"src_ip = "<<src_ip<<" , dst_ip = "<<dst_ip<<std::endl;
    start = clock();
    status = hal_route_entry_add(&key5, &data5);
    end = clock();
    // hal_route_aging_ttl_balance();
    // std::cout<<"========== new round insert end =========="<<std::endl;
    // printf("entry_in_table_c = %u\n",entry_in_table_c);
    // std::cout<<"status = "<<status<<std::endl;
    
    freopen("/share_test/proj_output/route_test.txt","a",stdout);

    if(status == BF_SUCCESS){
      su++;
      time_record += end - start;
      // std::cout<<"now insert: "<<su<<std::endl;
      // std::cout<<"in BF_SUCCESS"<<status<<std::endl;
      // printf("%u\n",su);
      if(su % 655 == 0){ //  1% of 65536
        std::cout<<"insert "<<su<<" time_cost= "<<time_record<<std::endl;
        time_record = 0;
        // break;
      }
      if(su==80000){
        std::cout<<"total insert "<<su<<std::endl;
        break;
      }
    }
    else{
      // exit(0);
      std::cout<<"error occur "<<su<<std::endl;
      std::cout<<"insert "<<su<<" time_cost= "<<time_record<<std::endl;
      break;
    }
  }
  freopen("/dev/tty", "w", stdout);
  // ratecout.close();

}


void flow_table_del_test(){
  uint64_t ipx=43434;
  uint32_t src_ip,dst_ip;
  hal_route_key key5;
  uint32_t status;

  while(1){
    ipx += 1;
    src_ip = (uint32_t)((ipx & 0xffff0000) >> 32);
    dst_ip = (uint32_t)((ipx & 0x0000ffff));
    key5.ip_src_addr = src_ip;
    key5.ip_dst_addr = dst_ip;
    
    status = hal_route_entry_del(&key5,false);

    if(status != BF_SUCCESS){
      break;
    }
    // std::cout<<"status = "<<status<<std::endl;
  }
}


void test_route(std::shared_ptr<bfrt::BfRtSession>& session){
  // freopen("/share_test/proj_output/route_test.txt","w",stdout);
  printf("====== Test test_route ======\n"); // 初始化可以帮助驱动提前分配空间，加快后续表项处理效率
  hal_route_key key1 = {.ip_src_addr=0xA000001, .ip_dst_addr=0xA0000A};
  hal_route_data data1 = {.nhop_id=255};
  hal_route_key key2 = {.ip_src_addr=0xA000002, .ip_dst_addr=0xA0000A};
  hal_route_data data2 = {.nhop_id=256};
  hal_route_key key3 = {.ip_src_addr=0xA000003, .ip_dst_addr=0xA0000A};
  hal_route_data data3 = {.nhop_id=65536};
  hal_route_key key4 = {.ip_src_addr=0xA000004, .ip_dst_addr=0xA0000A};
  hal_route_data data4 = {.nhop_id=4};

  // direct_replace = true;
  // yxj_entry_index = 100;
  hal_route_entry_add(&key1, &data1);
  // direct_replace = true;
  // yxj_entry_index = 100;
  hal_route_entry_add(&key2, &data2);
  // direct_replace = true;
  // yxj_entry_index = 100;
  hal_route_entry_add(&key3, &data3);
  // direct_replace = true;
  // yxj_entry_index = 120;
  hal_route_entry_add(&key4, &data4);
printf("data1 = %u, data2 = %u, data3 = %u, data4 = %u\n",data1.nhop_id,data2.nhop_id,data3.nhop_id,data4.nhop_id);
//   hal_route_entry_add(&key1, &data2);
//   hal_route_aging_ttl_balance();
//   hal_route_entry_add(&key2, &data3);
//   hal_route_aging_ttl_balance();
//   hal_route_entry_add(&key3, &data4);
//   hal_route_aging_ttl_balance();
//   hal_route_entry_add(&key4, &data1);
//   hal_route_aging_ttl_balance();

  std::cout << "Add finished" << std::endl;
  session->sessionCompleteOperations();

  hal_route_entry_get(&key1, &data1); //表内无表项时，会返回index最大的作为data的值
//   hal_route_aging_ttl_balance();
  hal_route_entry_get(&key2, &data2);
//   hal_route_aging_ttl_balance();
  hal_route_entry_get(&key3, &data3);
//   hal_route_aging_ttl_balance();
  hal_route_entry_get(&key4, &data4);
//   hal_route_aging_ttl_balance();
  printf("data1 = %u, data2 = %u, data3 = %u, data4 = %u\n",data1.nhop_id,data2.nhop_id,data3.nhop_id,data4.nhop_id);


//   std::cout << "=======================================" << std::endl;
  uint32_t entry_count;
//   hal_route_table_usage_get(&entry_count);
//   printf("table usage = %d\n", entry_count);
//   uint32_t size_;
//   hal_route_table_size_get(&size_);
//   printf("table size = %d\n", size_);
//   std::cout << "=======================================" << std::endl;

  
  hal_route_entry_del(&key1,false);
  hal_route_entry_del(&key2,false);
  hal_route_entry_del(&key3,false);
  hal_route_entry_del(&key4,false);

  printf("entry delete finished\n");
  session->sessionCompleteOperations();

  // freopen("/share_test/proj_output/route_test.txt","w",stdout);

  // std::cout << "flow_table_rate_test" << std::endl;
  // flow_table_rate_test();
  // std::cout << "flow_table_rate_test finish" << std::endl;
  // session->sessionCompleteOperations();
  // std::cout << "=======================================" << std::endl;

  // std::cout << "flow_table_del_test" << std::endl;
  // flow_table_del_test();
  // std::cout << "flow_table_del_test finish" << std::endl;


  hal_route_table_usage_get(&entry_count);
  printf("table usage = %d\n", entry_count);
  // freopen("/dev/tty", "w", stdout);


  printf("====== Test route end ======\n");
}