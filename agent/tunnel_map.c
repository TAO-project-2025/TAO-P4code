#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <sys/queue.h>

#include <rte_common.h>
#include <rte_byteorder.h>
#include <rte_log.h>
#include <rte_memory.h>
#include <rte_memcpy.h>
#include <rte_eal.h>

#include <rte_branch_prediction.h>
#include <rte_debug.h>
#include <rte_ether.h>
#include <rte_ethdev.h>
#include <rte_mempool.h>
#include <rte_mbuf.h>
#include <rte_malloc.h>
#include "rte_hash.h"
#include "rte_hash_crc.h"
#include "rte_jhash.h"
#include <rte_rwlock.h>

#include "ntb_errno.h"
#include "tunnel_map.h"
// #include "ntb_spec.h"
// #include "../platform/drivers/hal_table_type.h"
// #include "../platform/drivers/hal_table_api.h"
#include <hal_table_type.h>
#include <hal_table_api.h>

static int
_shc_hal_tunnel_map_vrf_entry_add(ntb_tunnel_type_t type, ntb_tunnel_id_t id, int32_t vrf_id) 
{
    hal_status_t ret;
    hal_tunnel_map_vrf_key key1;
    hal_tunnel_map_vrf_data data1;
    if (type == NTB_TUNNEL_VXLAN) {
        key1.tunnel_type = TYPE_TUNNEL_TYPE_VXLAN;
        key1.tunnel_key = id.vni;
        data1.vrf = vrf_id;
    } else {
        key1.tunnel_type = TYPE_TUNNEL_TYPE_GRE;
        key1.tunnel_key = id.vpcid;
        data1.vrf = id.vni;
    }

    ret = hal_tunnel_map_vrf_entry_add(&key1, &data1);
    if (ret != 0) {
        RTE_LOG(ERR, USER1, "_ntb_hal_tunnel_unmap_vrf call error: %s",
                            hal_status_to_string(ret)); 
        ret = NTB_LOAD_TO_P4_FAIL;
        return ret;
    }

    return 0;
}

static int
_shc_hal_tunnel_map_vrf_entry_del(ntb_tunnel_type_t type, ntb_tunnel_id_t id) 
{
    hal_status_t ret;
    hal_tunnel_map_vrf_key key1;
    if (type == NTB_TUNNEL_VXLAN) {
        key1.tunnel_type = TYPE_TUNNEL_TYPE_VXLAN;
        key1.tunnel_key = id.vni;
    } else {
        key1.tunnel_type = TYPE_TUNNEL_TYPE_GRE;
        key1.tunnel_key = id.vpcid;
    }

    ret = hal_tunnel_map_vrf_entry_del(&key1);
    if (ret != 0) {
        RTE_LOG(ERR, USER1, "_ntb_hal_tunnel_unmap_vrf call error: %s",
                            hal_status_to_string(ret)); 
        ret = NTB_LOAD_TO_P4_FAIL;
        return ret;
    }
    // ntb_spec_obj_ent_num_dec(NTB_TUNNEL_OBJ);
    return 0;
}


static struct rte_hash *vrf_hash_tbl;

struct tunnel_map_key {
    ntb_tunnel_type_t type;
    ntb_tunnel_id_t id;
} __rte_packed;

// create a map table
int
ntb_tunnel_map_vrf_init(void)
{
    struct rte_hash_parameters params1 = {
        .name = RTE_STR(VRF_MAPPING_HASH),
        .entries = NTB_NR_TUNNEL_ALL * 8,
        .hash_func = rte_jhash,
        .key_len = sizeof(struct tunnel_map_key),
    };

    vrf_hash_tbl = rte_hash_create(&params1);
    RTE_ASSERT(!!vrf_hash_tbl);
    rte_hash_reset(vrf_hash_tbl);

    return 0;
}

int
ntb_tunnel_map_vrf_deinit(void)
{
    return 0;
}



// add an entry
int
ntb_tunnel_map_vrf(const char *vrf_name, ntb_tunnel_type_t type,
                ntb_tunnel_id_t id, ntb_tunnel_attr_t tunnel_attr)
{
    struct tunnel_map_key map_key;
    struct ntb_tunnel_info *tunnel_i = NULL;
    ntb_vrf_t *vrf;
    int ret;

    vrf = ntb_vrf_lookup(vrf_name);
    if (NULL == vrf)
        return NTB_VRF_NOT_EXIST;

    /* If the tunnel has been created already.*/
    map_key.type = type;
    map_key.id = id;
    ret = rte_hash_lookup_data(vrf_hash_tbl, &map_key, (void**)&tunnel_i);
    if (ret >= 0) {
        RTE_ASSERT(tunnel_i != NULL);

        /* If the tunnel is mapped to other VRF already?.*/
        if (tunnel_i->vrf_id != vrf->dp.vrf_id)
            return NTB_TUNNEL_INUSED;

        return 0;
    }

    tunnel_i = rte_zmalloc(__func__, sizeof(*tunnel_i), 0);
    if (NULL == tunnel_i)
        return NTB_COMM_NOMEM;

    tunnel_i->vrf_id = vrf->dp.vrf_id;

    if (rte_hash_add_key_data(vrf_hash_tbl, &map_key, tunnel_i) < 0) {
        rte_free(tunnel_i);
        return NTB_TUNNEL_MAP_NOSPACE;
    }

   
    SLIST_INSERT_HEAD(&vrf->dp.tunnel_rmap, tunnel_i, next);
    vrf->dp.tunnel_cnt++;
    return 0;
}

/*
static inline int
__tunnel_unmap(ntb_tunnel_type_t type, ntb_tunnel_id_t id)
{
    struct tunnel_map_key map_key = {
        .type = type,
        .id = id,
    };

    if (rte_hash_del_key(vrf_hash_tbl, &map_key) < 0)
        return -1;  ENOENT 

    return 0;
}*/

// delete an entry
int
ntb_tunnel_unmap_vrf(ntb_tunnel_type_t type, ntb_tunnel_id_t id)
{
    struct ntb_tunnel_info *tunnel_i;
    vrf_dp_t *vrf_dp = NULL;
    int ret;

    struct tunnel_map_key map_key = {
        .type = type,
        .id = id,
    };
    ret = rte_hash_lookup_data(vrf_hash_tbl, &map_key, (void**)&tunnel_i);
    if (ret < 0) {
        return 0;  /* no exist, just return ok */
    }
    _shc_hal_tunnel_map_vrf_entry_del(type, id);// 立即删除规则

    vrf_dp = ntb_vrf_dp_get_by_id(tunnel_i->vrf_id);

    /* Tunnel unmapping.*/
    // ret = __tunnel_unmap(type, id);
    if (ret < 0) {
        /* entry not exits, just return ok */
        return 0;
    }

    /* Release the corresponding tunnel info.*/
    RTE_ASSERT(tunnel_i != NULL);
    SLIST_REMOVE(&vrf_dp->tunnel_rmap, tunnel_i, ntb_tunnel_info, next);
    rte_free(tunnel_i);
    vrf_dp->tunnel_cnt--;
    return 0;
}

/* for pmd lookup
说明：最后一个参数是标志位
    当flag_of_add_del = 0：下发规则，添加条目到硬件表中;
    当flag_of_add_del = 1：调用函数，删除硬件表中相应的条目。

*/
vrf_dp_t *
ntb_tunnel_map_vrf_lookup(ntb_tunnel_type_t type,
                ntb_tunnel_id_t id,int flag_of_add_del)
{
    int ret;
    vrf_dp_t *vrf_dp = NULL;
    struct ntb_tunnel_info *tunnel_i = NULL;
    struct tunnel_map_key map_key = {
        .type = type,
        .id = id,
    };

    ret = rte_hash_lookup_data(vrf_hash_tbl, &map_key, (void**)&tunnel_i);
    if (ret >= 0) {//查询到了
        RTE_ASSERT(tunnel_i != NULL);

        if(flag_of_add_del == 0){
            ret = _shc_hal_tunnel_map_vrf_entry_add(type, id, tunnel_i->vrf_id); //查询后立即下发规则
            RTE_ASSERT(ret != 0);
        }
        else{
            ret = _shc_hal_tunnel_map_vrf_entry_del(type,id);//删除硬件表中的相应表项
            RTE_ASSERT(ret != 0);
        }

        vrf_dp = ntb_vrf_dp_get_by_id(tunnel_i->vrf_id);
        RTE_ASSERT(vrf_dp != NULL);
    }

    return vrf_dp;
}

int
ntb_tunnel_map_cleanup(vrf_dp_t *vrf_dp)
{
    struct ntb_tunnel_info *tunnel_i;

    while (!SLIST_EMPTY(&vrf_dp->tunnel_rmap)) {
        tunnel_i = SLIST_FIRST(&vrf_dp->tunnel_rmap);
        SLIST_REMOVE_HEAD(&vrf_dp->tunnel_rmap, next);
        //__tunnel_unmap(tunnel_i->type, tunnel_i->id);
        // ntb_tunnel_bundle_cleanup(tunnel_i); 
        // _ntb_hal_tunnel_unmap_vrf(tunnel_i->type, tunnel_i->id);
        // _ntb_hal_ig_tunnel_statistics_del(vrf_dp, tunnel_i->type, tunnel_i->id);
        rte_free(tunnel_i);
        vrf_dp->tunnel_cnt--;
    }
    return 0;
}
