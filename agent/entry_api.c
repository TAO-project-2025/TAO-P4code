#include <stdio.h>
#include <stdlib.h>

#include "entry_api.h"
#include "tunnel_map.h"
#include "neigh.h"
#include "route.h"
#include "vrf.h"
#include "netio.h"
#include "stat.h"
#include "ntb_dp.h"
#include "ntb_errno.h"


int shc_swTohw_rule(uint32_t vni,uint32_t ip_src_addr,uint32_t ip_dst_addr,int flag_of_add_del)
{
    vrf_dp_t *vrf_dp = NULL;
    int ret = 0;
    struct fib_res *f_res;
    int nhsel = 0;
    struct rte_ether_addr *ethhdr;

    ntb_tunnel_id_t tunnel_id={
        .vni = vni,
        .vpcid = 0,
        .common_id = 0,
    };
    
    vrf_dp = ntb_tunnel_map_vrf_lookup(NTB_TUNNEL_VXLAN,tunnel_id,flag_of_add_del); //check tunnel map vrf table
    RTE_ASSERT(vrf_dp != NULL);

    ret = ntb_route_lookup(vrf_dp,ip_src_addr,ip_dst_addr,&f_res,flag_of_add_del);
    if(ret < 0)
        return ret;
    //ret = ntb_route_lookup(vrf_dp,iphdr->dst_addr,&f_res); //check vrf(route) table find the exact route path
    //ntb_neigh_looup(vrf_dp->vrf_id,f_res->mpath[nhsel]->gateway,&ethhdr->d_addr);
    
    ret = ntb_neigh_lookup(vrf_dp->vrf_id,f_res->mpath[nhsel]->gateway,&ethhdr->d_addr,flag_of_add_del);
    if(ret < 0)
        return ret;
    //trte_ether_addr_copy(ntb_fake_mac_get(),&ethhdr->s_addr);

    return 0;
}


/*
    tunnel_map_vrf表
        key:tunnel_type + vni
        value:vrf_id
    
    route表
        key:vrf_id + inner_src_ip + inner_dst_ip
        value:nhop_id
    
    nhop_info表
        key:nhop_id
        value:out_src_ip + out_dst_ip + neigh_id
    
    neigh表
        key:neigh_id
        value:dmac
  
    route表
        在软件表上，vrfid + dstip -> f_res_id
        f_res_id 查 fib_res_array 得到 fib_res 这个结构体
            fib_res结构体中有fr_flags mpath_cnt mpath_max mpath[] oid
            mpath[]结构体中有gateway tunnel_info oid
*/
