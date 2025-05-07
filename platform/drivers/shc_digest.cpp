#include "shc_digest.hpp"
#include "hal_table_api.h"
#include<iostream>
#include<fstream>
#include<stdlib.h>
#include<iomanip>
#include <chrono>
#include "test_hal/test.hpp"

/***********************************************************************************
 * This sample cpp application code is based on the P4 program tna_digest.p4
 * Please refer to the P4 program and the generated bf-rt.json for information
 *on
 * the tables contained in the P4 program, and the associated key and data
 *fields.
 **********************************************************************************/

namespace shc {

std::map<std::string,ac_info> flows;
uint32_t flow_count[6000]={0};
uint32_t all_pkt_count[6000]={0};
uint32_t hit_ac_count[6000]={0};
clock_t start=0,end=0;
clock_t off_start,off_end;
uint32_t time_s=0;
uint32_t total_insert = 0;
uint32_t real_count = 0;
uint32_t fake_count = 0;
uint32_t error_count = 0;
//-------para for digest-------//

  uint64_t ip_src_addr;
  uint64_t ip_dst_addr;
  // uint64_t protocol;
  // uint64_t port_dst_addr;
  // uint64_t port_src_addr;
  // uint64_t time_stamp;
  uint64_t count;
  // uint64_t entry_index;  
  uint64_t ac_count;

  uint64_t hit_p;
  uint64_t ac_p;
  uint64_t cuckoo_hash1;
  uint64_t cuckoo_hash2;
  uint64_t cuckoo_hash3;
  uint64_t cuckoo_hash4;

// Learn field-ids
  // bf_rt_id_t learn_port_field_id = 0;
  // bf_rt_id_t learn_type_field_id = 0;
  // bf_rt_id_t learn_vni_digest_field_id = 0;
  bf_rt_id_t learn_src_ip_digest_field_id = 0;
  bf_rt_id_t learn_dst_ip_digest_field_id = 0;
  // bf_rt_id_t learn_protocol_digest_field_id = 0;
  // bf_rt_id_t learn_dst_port_digest_field_id = 0;
  // bf_rt_id_t learn_src_port_digest_field_id = 0;
  // bf_rt_id_t learn_time_stamp_field_id = 0;  
  // bf_rt_id_t learn_count_field_id = 0; 
  // bf_rt_id_t learn_entry_index_field_id = 0; 
  bf_rt_id_t learn_ac_count_field_id = 0;
  // bf_rt_id_t learn_hit_p_field_id = 0;
  // bf_rt_id_t learn_ac_p_field_id = 0;
  // bf_rt_id_t learn_cuckoo_hash1_field_id = 0;
  // bf_rt_id_t learn_cuckoo_hash2_field_id = 0;
  // bf_rt_id_t learn_cuckoo_hash3_field_id = 0;
  // bf_rt_id_t learn_cuckoo_hash4_field_id = 0;
  // bfrt related
  const bfrt::BfRtLearn *learn_obj;
  // std::shared_ptr<bfrt::BfRtSession> session_;
  // bf_rt_target_t dev_tgt_;   
/**********************************************************************
 * CALLBACK funciton that gets invoked upon a learn event
 *  1. session : Session object that was used to register the callback. This is
 *               the session that has to be used to manipulate the table in
 *response to a learn
 *               event. Its always advisable to use a single session to
 *manipulate a single
 *               table.
 *  2. vec : Vector of learnData objects
 *  3. learn_msg_hdl : Pointer to the underlying learn message object, on which
 *                     an ack needs to be done in order for the hardware
 *resource to be freed up.
 *                     This is to be done once all the processing on the learn
 *update is done.
 *
 *********************************************************************/

bf_status_t learn_callback(const bf_rt_target_t &bf_rt_tgt,
                           std::shared_ptr<bfrt::BfRtSession> session,
                           std::vector<std::unique_ptr<bfrt::BfRtLearnData>> data,
                           bf_rt_learn_msg_hdl *const learn_msg_hdl,
                           const void *cookie) {
  /***********************************************************
   * INSERT CALLBACK IMPLEMENTATION HERE
   **********************************************************/
  // std::ofstream mycout("/share_test/active_flowset.txt",std::ios::app);
  // Extract learn data fields from Learn Data object and use it as needed.
    // std::vector<std::unique_ptr<bfrt::BfRtLearnData>> digest;
  
    for (auto const &digest : data){

      // port = 0;
      // dtype = 0;
      // vni = 0;
      ip_src_addr = 0;
      ip_dst_addr = 0;
      // protocol = 0;
      // port_dst_addr = 0;
      // port_src_addr = 0;
      // time_stamp = 0;
      ac_count = 0;

      // digest->getValue(learn_port_field_id, &port);
      // digest->getValue(learn_type_field_id, &dtype);
      // digest->getValue(learn_vni_digest_field_id, &vni);
      digest->getValue(learn_src_ip_digest_field_id, &ip_src_addr);
      digest->getValue(learn_dst_ip_digest_field_id, &ip_dst_addr);
      // digest->getValue(learn_protocol_digest_field_id, &protocol);
      // digest->getValue(learn_dst_port_digest_field_id, &port_dst_addr);
      // digest->getValue(learn_src_port_digest_field_id, &port_src_addr);
      // digest->getValue(learn_time_stamp_field_id, &time_stamp);
      // digest->getValue(learn_count_field_id, &count);
      // digest->getValue(learn_entry_index_field_id, &entry_index);
      digest->getValue(learn_ac_count_field_id, &ac_count);

      // digest->getValue(learn_hit_p_field_id, &hit_p);
      // digest->getValue(learn_ac_p_field_id, &ac_p);
      // digest->getValue(learn_cuckoo_hash1_field_id, &cuckoo_hash1);
      // digest->getValue(learn_cuckoo_hash2_field_id, &cuckoo_hash2);
      // digest->getValue(learn_cuckoo_hash3_field_id, &cuckoo_hash3);
      // digest->getValue(learn_cuckoo_hash4_field_id, &cuckoo_hash4);

      // std::cout<<"cuckoo_hash1 = "<<cuckoo_hash1<<std::endl;
      // std::cout<<"cuckoo_hash2 = "<<cuckoo_hash2<<std::endl;
      // std::cout<<"cuckoo_hash3 = "<<cuckoo_hash3<<std::endl;
      // std::cout<<"cuckoo_hash4 = "<<cuckoo_hash4<<std::endl;

      // std::cout<<"ip_src_addr = "<<static_cast<uint32_t>(ip_src_addr)<<std::endl;
      // std::cout<<"ip_dst_addr = "<<static_cast<uint32_t>(ip_dst_addr)<<std::endl;

      // mycout<<static_cast<uint32_t>(ip_src_addr)<<","<<static_cast<uint32_t>(ip_dst_addr)<<","<<time_stamp<<","<<entry_index<<std::endl;
      // mycout<<static_cast<uint32_t>(count)<<std::endl;
      hal_route_key key = {.ip_src_addr=static_cast<uint32_t>(ip_src_addr), .ip_dst_addr=static_cast<uint32_t>(ip_dst_addr)};
      hal_route_data data = {.nhop_id=1};
      
      std::string key_string = std::to_string(key.ip_src_addr) + "," + std::to_string(key.ip_dst_addr);

      // if(all_pkt_count[0]==0){
      //   start = clock();
      // }    
      // end = clock();
      // if(end - start >= 1000000){ // 1s
      //   start = clock();
      //   time_s ++;
      // }
      // else{
      //   all_pkt_count[time_s] = ac_p*0xFFFFFFFF + ac_count;
      //   hit_ac_count[time_s] = hit_p*0xFFFFFFFF + count;
      // }
      
      // std::cout<<key_string<<" "<<std::to_string(key.ip_dst_addr)<<" "<<std::to_string(key.ip_src_addr)<<std::endl;
      // std::cout<<key.ip_dst_addr<<" "<<key.ip_src_addr<<std::endl;
      // auto currentTime = std::chrono::system_clock::now();
      // auto currentTimeStamp = std::chrono::duration_cast<std::chrono::seconds>(currentTime.time_since_epoch()).count(); 
        
      // direct_replace = true;
      // std::cout<<"========== 1 ========== "<<entry_index<<std::endl;
      // yxj_entry_index = static_cast<uint32_t>(entry_index);
      // yxj_entry_index = 100;
      // std::cout<<"========== 2 =========="<<std::endl;
      // off_start = clock();
      int stu_2 = hal_route_entry_add(&key, &data);
      // off_end = clock();

      // if(flow_count[0]==0){
      //   start = clock();
      //   flow_count[0] = 1;
      // }    
      // end = clock();
      // if(end - start >= 1000000){ // 1s
      //   start = clock();
      //   time_s ++;
      // }
      // else{
      //   flow_count[time_s]++;
      //   // all_pkt_count[time_s] = ac_p*4294967295 + ac_count;
      //   // hit_ac_count[time_s] = hit_p*4294967295 + count;
      // }

      // if(ip_src_addr == 3232235777 && flows.find(key_string) == flows.end()){ 
      // if(flows.find(key_string) == flows.end()){
      //   // std::cout<<key_string<<" "<<std::to_string(key.ip_dst_addr)<<" "<<std::to_string(key.ip_src_addr)<<std::endl;
      //   flows[key_string].pkt_num = ac_count;
      //   // flows[key_string].time_stamp_h = time_stamp;
      //   flows[key_string].time_stamp_s = off_end - off_start;
      //   // std::cout<<key_string<<" "<<flows[key_string].time_stamp_h<<" "<<flows[key_string].time_stamp_s<<std::endl;
      // }
      // std::cout<<"========== 3 =========="<<std::endl;
      // std::cout<<"========== active flow add =========="<<std::endl;


      
      if(stu_2 == 0){
        // std::cout<<"========== active flow add =========="<<std::endl;
        total_insert ++;
        // printf("entry_in_table_c = %u\n",entry_in_table_c);
        // std::cout<<"total_insert = "<<total_insert<<std::endl;
        hal_route_aging_ttl_balance();
      }
      // else{
      //   direct_replace = true;
      //   yxj_entry_index = static_cast<uint32_t>(entry_index);
      //   hal_route_entry_add(&key, &data);
      //   direct_replace = false;
      // }

      // printf("proto = %lu, entry_index = %lu\n",count,entry_index);


    }

  /*********************************************************
  * WHEN DONE, ACK THE learn_msg_hdl
  ********************************************************/
  // (void)bf_rt_tgt; //避免了未使用的变量警告
  // (void)data;
  // (void)cookie;
  // printf("Learn callback invoked\n");
  auto bf_status = learn_obj->bfRtLearnNotifyAck(session, learn_msg_hdl);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // mycout.close();
  
  return BF_SUCCESS;
}

void ShcDigest(const bfrt::BfRtInfo *bfrtInfo, bf_rt_target_t& d_tgt, std::shared_ptr<bfrt::BfRtSession>& session){

  // dev_tgt_.dev_id = d_tgt.dev_id;
  // dev_tgt_.pipe_id = d_tgt.pipe_id; 

//----------------------------------------------------------------------------//
  /***********************************************************************
   * LEARN OBJECT GET FOR "digest" extern
   **********************************************************************/
  bf_status_t bf_status = bfrtInfo->bfrtLearnFromNameGet("ShcIngressDeparser.flowkey_digest",
                                             &learn_obj);
  bf_sys_assert(bf_status == BF_SUCCESS);

  /***********************************************************************
   * LEARN FIELD ID GET FROM LEARN OBJECT
   **********************************************************************/
  // bf_status =
  //     learn_obj->learnFieldIdGet("port", &learn_port_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = learn_obj->learnFieldIdGet("type", &learn_type_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("vni_digest", &learn_vni_digest_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status =
      learn_obj->learnFieldIdGet("src_ip_digest", &learn_src_ip_digest_field_id);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status = learn_obj->learnFieldIdGet("dst_ip_digest", &learn_dst_ip_digest_field_id);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = learn_obj->learnFieldIdGet("cuckoo_hash_1", &learn_cuckoo_hash1_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = learn_obj->learnFieldIdGet("cuckoo_hash_2", &learn_cuckoo_hash2_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = learn_obj->learnFieldIdGet("cuckoo_hash_3", &learn_cuckoo_hash3_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = learn_obj->learnFieldIdGet("cuckoo_hash_4", &learn_cuckoo_hash4_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("protocol", &learn_protocol_digest_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = learn_obj->learnFieldIdGet("dst_port", &learn_dst_port_digest_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("src_port", &learn_src_port_digest_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("time_stamp", &learn_time_stamp_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("hit_count", &learn_count_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("entry_index", &learn_entry_index_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status =
      learn_obj->learnFieldIdGet("ac_count", &learn_ac_count_field_id);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("hit_p", &learn_hit_p_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     learn_obj->learnFieldIdGet("ac_p", &learn_ac_p_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  /***********************************************************************
   * LEARN callback registration
   **********************************************************************/
  bf_status = learn_obj->bfRtLearnCallbackRegister(
      session, d_tgt, learn_callback, NULL);
  bf_sys_assert(bf_status == BF_SUCCESS);
  printf("bfRtLearnCallbackRegister---------\n");
//----------------------------------------------------------------------------//

}
// This function does the initial set up of getting key field-ids, action-ids
// and data field ids associated with the smac table. This is done once
// during init time.

int shc_digest_init(const bfrt::BfRtInfo *bfrtInfo, bf_rt_target_t& dev_tgt, std::shared_ptr<bfrt::BfRtSession>& session) {
  int status = 0;

  shc::ShcDigest(bfrtInfo, dev_tgt, session);
  printf("------------------------- shc_digest_init -------------------------\n");

  // HAL_LOG_INFO(LOG_USER1, "vrfmapping_init finish.");
  return status;
}

}  // shc_digest
// int main(int argc, char **argv) {
//   parse_opts_and_switchd_init(argc, argv);

//   // Do initial set up
//   bfrt::examples::shc_digest::setUp();
//   // Do table level set up
//   bfrt::examples::shc_digest::tableSetUp();

//   run_cli_or_cleanup();
//   return 0;
// }