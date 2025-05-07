#include "shc_aging.hpp"
#include "hal_table_api.h"
#include<iostream>
#include<iomanip>
// #include <bf_rt/bf_rt_table_attributes.hpp>
// #include "test_hal/test.hpp"



/************************************************************************************
 * This example demonstarates the following for a P4 table with idle_timeout set
 *to True
 * 1. Allocate an attribute object and enable idle time out in NOTIFY_MODE with
 *required parameters.
 * 2. Using the attirbute object to call the attribute set API on table object.
 * 3. A hook for idle time out callback implementation.
 ********************************************************************/

namespace shc {
  uint32_t total_aged = 0;
  //-------para for aging-------//
  // uint64_t aging_vrf;
  uint64_t aging_ip_src;
  uint64_t aging_ip_dst;
  // uint64_t aging_protocol;
  // uint64_t aging_port_dst;
  // uint64_t aging_port_src;
  // Aging field-ids
  // bf_rt_id_t aging_vrf_field_id = 0;
  bf_rt_id_t aging_ip_src_field_id = 0;
  bf_rt_id_t aging_ip_dst_field_id = 0;
  // bf_rt_id_t aging_protocol_field_id = 0;
  // bf_rt_id_t aging_port_dst_field_id = 0;
  // bf_rt_id_t aging_port_src_field_id = 0;

// Key field ids, table data field ids, action ids, Table object required for
// interacting with the table
// const bfrt::BfRtLearn *learn_obj = nullptr;
const bfrt::BfRtTable *route_ = nullptr;
// std::shared_ptr<bfrt::BfRtSession> session;

std::unique_ptr<bfrt::BfRtTableAttributes> attr;
bf_rt_target_t dev_tgt_;

/**********************************************************************
 * CALLBACK funciton that gets invoked upon a entry agin event. One per entry
 *  1. target : Device target from which the entry is aging out
 *  2. key : Pointer to the key object representing the entry which has aged out
 *  3. cookie : Pointer to the cookie which was given at the time of the
 *callback registration
 *
 *********************************************************************/
bf_status_t idletime_callback(const bf_rt_target_t &target,
                              const bfrt::BfRtTableKey *key,
                              const void *cookie) {
  (void)cookie;
  // printf("idletime_callback---------\n");                             
  /***********************************************************
   * INSERT CALLBACK IMPLEMENTATION HERE
   **********************************************************/


  // aging_vrf = 0;
  aging_ip_src = 0;
  aging_ip_dst = 0;
  // aging_protocol = 0;
  // aging_port_dst = 0;
  // aging_port_src = 0;

  // key->getValue(aging_vrf_field_id, &aging_vrf);
  key->getValue(aging_ip_src_field_id, &aging_ip_src);
  key->getValue(aging_ip_dst_field_id, &aging_ip_dst);
  // key->getValue(aging_protocol_field_id, &aging_protocol);
  // key->getValue(aging_port_dst_field_id, &aging_port_dst);
  // key->getValue(aging_port_src_field_id, &aging_port_src);


//函数入口有参数key，函数内部不能再定义相同名字 key
  hal_route_key key2 = {.ip_src_addr=static_cast<uint32_t>(aging_ip_src), .ip_dst_addr=static_cast<uint32_t>(aging_ip_dst)};
  // hal_route_data data = {.nhop_id=static_cast<uint32_t>(vni)};
  int stu_2 = hal_route_entry_del(&key2,true); // tag aged
  // std::cout<<"========== aged rule taged =========="<<std::endl;
  // int stu_2 = hal_route_entry_del(&key2,false); // delete
  // 成功标记才能加一
  if(stu_2 == 1){ // 返回值为1表示成功添加aged标志
    // printf("entry_aged_c = %u\n",entry_aged_c);
    // std::cout<<"========== aged rule taged =========="<<std::endl;
    total_aged ++;
    // std::cout<<"total_aged = "<<total_aged<<std::endl;
    hal_route_aging_ttl_balance();
    // std::cout<<"========== aged rule taged end =========="<<std::endl;
  }

  // std::cout //<< "  vrf= " << std::setbase(10) <<static_cast<uint16_t>(aging_vrf) 
  //           // << "  ip_src_addr = 0x"<< std::setbase(16) << static_cast<uint32_t>(aging_ip_src) 
  //           << "  ip_dst_addr = "<< std::setbase(10) << static_cast<uint32_t>(aging_ip_dst) 
  //           // << "  entry aging and delete-----"<< "  status_1 = " <<stu_1 << "  status_2 = " <<stu_2 << std::endl
  //           // << "  entry aging and delete-----"<< "  status_2 = " <<stu_2 << std::endl;
  //           // << "dev_tgt_.dev_id = " << target.dev_id << "dev_tgt_.pipe_id = " <<target.pipe_id
  //           << std::endl;

  return BF_SUCCESS;
}

// This function does the initial set up of getting key field-ids, action-ids
// and data field ids associated with the smac table. This is done once
// during init time.
void ShcAging(const bfrt::BfRtInfo *bfrtInfo, bf_rt_target_t& dev_tgt, std::shared_ptr<bfrt::BfRtSession> &session){

  dev_tgt_.dev_id = dev_tgt.dev_id;
  dev_tgt_.pipe_id = dev_tgt.pipe_id; 

  // Get table object from name
  bf_status_t bf_status = bfrtInfo->bfrtTableFromNameGet("pipe.ShcIngress.route_tbl", &route_);
  bf_sys_assert(bf_status == BF_SUCCESS);

  /***********************************************************************
   * LEARN FIELD ID GET FROM LEARN OBJECT
   **********************************************************************/
  // bf_status =
  //     route_->keyFieldIdGet("ig_md.vrf", &aging_vrf_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status = route_->keyFieldIdGet("ig_md.src_addr", &aging_ip_src_field_id);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status =
      route_->keyFieldIdGet("ig_md.dst_addr", &aging_ip_dst_field_id);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = route_->keyFieldIdGet("hdr.ipv4.protocol", &aging_protocol_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status =
  //     route_->keyFieldIdGet("ig_md.dst_port", &aging_port_dst_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = route_->keyFieldIdGet("ig_md.src_port", &aging_port_src_field_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  /***********************************************************************
   * ALLOCATE TABLE ATTRIBUTE FOR ENABLING IDLE TIMEOUT AND REGISTER A CALLBACK
   **********************************************************************/
  bf_status =
      route_->attributeAllocate(bfrt::TableAttributesType::IDLE_TABLE_RUNTIME,
                                   bfrt::TableAttributesIdleTableMode::NOTIFY_MODE,
                                   &attr);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Set min_ttl to 50 ms, max_ttl to 5000 ms and ttl_query intervale to 50 ms
  uint32_t min_ttl = 0;
  uint32_t max_ttl = 50000;
  uint32_t ttl_query_interval = 50;
  void *cookie = nullptr;

  bf_status = attr->idleTableNotifyModeSet(
      false, NULL, ttl_query_interval, max_ttl, min_ttl, NULL);

  bf_status = attr->idleTableNotifyModeSet(
      true, shc::idletime_callback, ttl_query_interval, max_ttl, min_ttl, cookie);
  bf_sys_assert(bf_status == BF_SUCCESS);
  printf("idleTableNotifyModeSet---------\n");
  /***********************************************************************
   * CALL ATTRIBUTE SET API ON TABLE OBJECT
   **********************************************************************/
  uint32_t flags = 0;
  bf_status =
      route_->tableAttributesSet(*session, dev_tgt_, flags, *attr.get());
  bf_sys_assert(bf_status == BF_SUCCESS);
  printf("tableAttributesSet---------\n");

}

int shc_aging_init(const bfrt::BfRtInfo *bfrtInfo, bf_rt_target_t& dev_tgt, std::shared_ptr<bfrt::BfRtSession>& session) {
  int status = 0;

  shc::ShcAging(bfrtInfo, dev_tgt, session);
  printf("------------------------- shc_aging_init -------------------------\n");

  return status;
}

}  // shc_aging

// int main(int argc, char **argv) {
//   parse_opts_and_switchd_init(argc, argv);

//   // Do initial set up
//   bfrt::examples::tna_idletimeout::setUp();
//   // Do table level set up
//   bfrt::examples::tna_idletimeout::tableSetUp();

//   run_cli_or_cleanup();
//   return 0;
// }

