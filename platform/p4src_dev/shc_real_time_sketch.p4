/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;
typedef bit<24> vni_t;

const bit<16> ETHERTYPE_IPV4 = 0x0800;


const int HASH_BUCKET_WIDTH = 16;
typedef bit<(HASH_BUCKET_WIDTH)> hash_bucket_t;
const int HASH_BUCKET = 65536;
const int HIT_COUNT = 15;
// const bit<16> PROB_NUM = 32768; //若改成int类型与bit<16>进行饱和减，其结果有问题。条件 >0 不生效。 6554 9806 13108 65535

const bit<3> ACTIVE_FLOW_LEARN_DIGEST = 1;

header ethernet_h { //14B
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

header ipv4_h { //20B
    bit<4> version;
    bit<4> ihl;
    bit<6> dscp;
    bit<2> ecn;
    bit<16> total_len;
    bit<16> identification;
    bit<3> flags;
    bit<13> frag_offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header udp_h { //8B
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length;
    bit<16> checksum;
}

header vxlan_h { //8B
    bit<8> flags;
    bit<24> reserved;
    bit<24> vni;
    bit<8> reserved2;
}

header cuckoo_hashes_h{
    bit<32> cuckoo_hash1;
    bit<32> cuckoo_hash2;
    bit<32> cuckoo_hash3;
    bit<32> cuckoo_hash4;
}

struct shc_header_t { //
    ethernet_h ethernet;
    ipv4_h ipv4;
    udp_h udp;
    vxlan_h vxlan;
    ethernet_h inner_ethernet;
    ipv4_h inner_ipv4;  
    cuckoo_hashes_h cuckoo_hashes;
}

struct shc_ingress_metadata_t {
    // for sketch
    bit<24> vni;
    bit<32> src_addr;
    bit<32> dst_addr;

    bit<32> pkt_n_c;
    bit<1>  pkt_n_done_flag; 

    hash_bucket_t hash_index;
    bit<16> fingerprint;
    bit<1>  fp_cmp_re;
    bit<8> cs_count;
    bit<1> hash_index_done;

    // 输出参数
    bit<1> eflag;

    // for digest
    bit<48> time_stamp;

    // for route
    bit<32> nhop_id;

    bit<16> cuckoo_hash_index;
}

//ingress parser
parser ShcIngressParser(
        packet_in pkt,
        out shc_header_t hdr,
        out shc_ingress_metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        ig_md.eflag = 0;
        ig_md.cs_count = 0;
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4:  parse_ipv4;

            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ig_md.src_addr = hdr.ipv4.src_addr;
        ig_md.dst_addr = hdr.ipv4.dst_addr;
        transition select(hdr.ipv4.protocol) {
            17 :  parse_udp;
            100:  parse_cuckoo_hashes;

            default: accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port) {
            4789 : parse_vxlan;
            default : accept;
        }
    }

    state parse_cuckoo_hashes { //receive 
        pkt.extract(hdr.cuckoo_hashes);

        transition accept;
    }

    state parse_vxlan {
        pkt.extract(hdr.vxlan);
        ig_md.vni = hdr.vxlan.vni;
        ig_md.eflag = 0;
        transition parse_inner_ethernet;
    }

    state parse_inner_ethernet {
        pkt.extract(hdr.inner_ethernet);
        transition select(hdr.inner_ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_inner_ipv4;
            default : accept;
        }
    }

    state parse_inner_ipv4 {
        pkt.extract(hdr.inner_ipv4);
        // ig_md.src_addr = hdr.inner_ipv4.src_addr;
        // ig_md.dst_addr = hdr.inner_ipv4.dst_addr;
        transition accept;
    }
}

// sketch 
control Sketch(//in shc_header_t hdr, // 定义为hdr 若定义为in bit<16> len编译无错，执行时会报错
               inout shc_ingress_metadata_t ig_md)()
{
    // record total number of pkts
    Register<bit<32>,bit<1>>(1,0) pkt_num;
    RegisterAction<bit<32>,bit<1>,bit<32>>(pkt_num) pkt_num_count={
		void apply(inout bit<32> register_data, out bit<32> pkt_n){
            register_data = register_data |+| 1;
            pkt_n = register_data;
		}
	};

    action count_pkt_num(){
        ig_md.pkt_n_c = pkt_num_count.execute(0);
        ig_md.pkt_n_done_flag = 1;
    }
    table count_pkt_num_table{
        actions = {
            count_pkt_num();
        }
        size = 1;
        const default_action = count_pkt_num();
    }
    
    /* CRC32  as crc32_1*/
    // CRCPolynomial<bit<32>>(coeff=0x04C11DB7,reversed=true, msb=false, extended=false, init=0xFFFFFFFF, xor=0xFFFFFFFF) crc32_1;
    // CRCPolynomial<bit<32>>(coeff=0x1EDC6F41,reversed=true, msb=false, extended=false, init=0xFFFFFFFF, xor=0xFFFFFFFF) crc32_2;
    // Hash<hash_bucket_t>(HashAlgorithm_t.CUSTOM, crc32_1) hash1;
    // Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc32_2) hash2;


    // compute hash_index and fingerprint of a flow
    Hash<hash_bucket_t>(HashAlgorithm_t.RANDOM) hash1; // for number of buckets
    Hash<bit<16>>(HashAlgorithm_t.CRC16) hash2; // for fingerprint

    action get_hash_value(){
        ig_md.hash_index = hash1.get({ig_md.src_addr, ig_md.dst_addr});
        ig_md.fingerprint = hash2.get({ig_md.src_addr, ig_md.dst_addr});
    }
    table get_hash_value_table{ 
        actions = {
            get_hash_value;
        }
        size = 1;
        default_action = get_hash_value();
    }
    
    // update fingerprint in the bucket according to hash_index
    Register<bit<16>,hash_bucket_t>(HASH_BUCKET) hash1_1;
    RegisterAction<bit<16>,hash_bucket_t,bit<1>>(hash1_1) pkt_update_1={
		void apply(inout bit<16> register_data, out bit<1> pkt_num_o){
            if(ig_md.fingerprint == register_data){
                pkt_num_o = 1; 
            }
            else{
                pkt_num_o = 0;
                register_data = ig_md.fingerprint;
            }
		}
	};
    action update_pkt_1(){
        ig_md.fp_cmp_re = pkt_update_1.execute(ig_md.hash_index);
        ig_md.hash_index_done = 1;
    }    
    table update_pkt_1_table{
        actions = {
            update_pkt_1;
        }
        size = 1;
        default_action = update_pkt_1();
    }

    // update the consecutively arriving count in the bucket according to hash_index and the result of fingerprint
    Register<bit<8>,hash_bucket_t>(HASH_BUCKET,1) hash1_1_n;
    RegisterAction<bit<8>,hash_bucket_t,bit<8>>(hash1_1_n) pkt_num_1={
		void apply(inout bit<8> register_data, out bit<8> pkt_num_o){
            if(ig_md.fp_cmp_re == 1){
                register_data = register_data |+| 1;
            }
            else{
                register_data = 1;
            }
            pkt_num_o = register_data;
		}
	};
    action update_pkt_num_1(){
        ig_md.cs_count = pkt_num_1.execute(ig_md.hash_index);
    }    
    table update_pkt_num_1_table{
        actions = {
            update_pkt_num_1;
        }
        size = 1;
        default_action = update_pkt_num_1();
    }

    apply {
        count_pkt_num_table.apply();

        get_hash_value_table.apply(); // 0
        update_pkt_1_table.apply(); // 
            
        if(ig_md.hash_index_done == 1){
            update_pkt_num_1_table.apply(); 
            if(ig_md.cs_count == HIT_COUNT){
                ig_md.eflag = 1;
            }
            else{
                ig_md.eflag = 0;
            }
        }
    }
}

control ShcIngress( inout shc_header_t hdr,
                 inout shc_ingress_metadata_t ig_md,
                 
                 in    ingress_intrinsic_metadata_t               ig_intr_md,
                 in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
                 inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
                 inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md    )
{

    Sketch() sk;


    // 测试数据包中携带的hash值
    Register<bit<32>,bit<1>>(1,0) cuckoo_hash_rec1;
    RegisterAction<bit<32>,bit<1>,bit<32>>(cuckoo_hash_rec1) cuckoo_hash_rec_1={
		void apply(inout bit<32> register_data, out bit<32> pkt_n){
            register_data = hdr.cuckoo_hashes.cuckoo_hash1;
		}
	};

    Register<bit<32>,bit<1>>(1,0) cuckoo_hash_rec2;
    RegisterAction<bit<32>,bit<1>,bit<32>>(cuckoo_hash_rec2) cuckoo_hash_rec_2={
		void apply(inout bit<32> register_data, out bit<32> pkt_n){
            register_data = hdr.cuckoo_hashes.cuckoo_hash2;
		}
	};

    Register<bit<32>,bit<1>>(1,0) cuckoo_hash_rec3;
    RegisterAction<bit<32>,bit<1>,bit<32>>(cuckoo_hash_rec3) cuckoo_hash_rec_3={
		void apply(inout bit<32> register_data, out bit<32> pkt_n){
            register_data = hdr.cuckoo_hashes.cuckoo_hash3;
		}
	};

    Register<bit<32>,bit<1>>(1,0) cuckoo_hash_rec4;
    RegisterAction<bit<32>,bit<1>,bit<32>>(cuckoo_hash_rec4) cuckoo_hash_rec_4={
		void apply(inout bit<32> register_data, out bit<32> pkt_n){
            register_data = hdr.cuckoo_hashes.cuckoo_hash4;
		}
	};


    action route_for_nexthop(bit<32> nhop_id){
        ig_md.nhop_id = nhop_id;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        // ig_tm_md.ucast_egress_port = 160;

        ig_md.time_stamp = ig_intr_md.ingress_mac_tstamp;
    }
    action route_for_miss(){
        ig_tm_md.ucast_egress_port = 160;
        ig_tm_md.bypass_egress = 1;
        ig_md.time_stamp = 0;
    }
    @idletime_precision(3)
    table route_tbl{
        key = {
            // ig_md.vrf : exact;
            hdr.ipv4.src_addr : exact;
            hdr.ipv4.dst_addr : exact;
        }
        actions = {
            route_for_nexthop;
            route_for_miss;
        }
        const default_action = route_for_miss;
        size = 65536;
        idle_timeout = true;
    }
    
    apply{
        if (hdr.ipv4.isValid()) { 
            if(hdr.cuckoo_hashes.isValid()){
                cuckoo_hash_rec_1.execute(0);
                cuckoo_hash_rec_2.execute(0);
                cuckoo_hash_rec_3.execute(0);
                cuckoo_hash_rec_4.execute(0);
            }
            sk.apply(ig_md);
            route_tbl.apply();

            // ig_md.cuckoo_hash_index = route_tbl.apply().key; //

            if(ig_md.eflag == 1 && ig_tm_md.bypass_egress == 1){
                ig_dprsr_md.digest_type = ACTIVE_FLOW_LEARN_DIGEST;
            }
            else{
                ig_dprsr_md.digest_type = 0;
            }
        }
    }
}
// 当使用两个digest时，会出现32bit container Consecutive location 的错误，应该是巧合
// 由于PortId_t为16bit，与后面的bit<16> vrf_digest 凑成一个32bit，编译器会将两个16bit放在同一个32bit container里面，导致出错

struct flowkey_digest_t {
    bit<32> src_ip_digest;
    bit<32> dst_ip_digest;
    bit<48> time_stamp;
    bit<32> count;
    bit<32> entry_index;
}

//ingress deparser
control ShcIngressDeparser(
    packet_out pkt,
    inout shc_header_t hdr,
    in shc_ingress_metadata_t ig_md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md){

    Digest<flowkey_digest_t>() flowkey_digest;

    Checksum() ipv4_checksum;
    Checksum() inner_ipv4_checksum;

    apply {
        if(ig_dprsr_md.digest_type == ACTIVE_FLOW_LEARN_DIGEST){
            flowkey_digest.pack({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                ig_md.time_stamp,
                ig_md.pkt_n_c,
                ig_md.nhop_id
            });
        }       

        hdr.ipv4.hdr_checksum = ipv4_checksum.update({
            hdr.ipv4.version,
            hdr.ipv4.ihl,
            hdr.ipv4.dscp,
            hdr.ipv4.ecn,
            hdr.ipv4.total_len,
            hdr.ipv4.identification,
            hdr.ipv4.flags,
            hdr.ipv4.frag_offset,
            hdr.ipv4.ttl,
            hdr.ipv4.protocol,
            hdr.ipv4.src_addr,
            hdr.ipv4.dst_addr});

        
        hdr.inner_ipv4.hdr_checksum = inner_ipv4_checksum.update({
            hdr.inner_ipv4.version,
            hdr.inner_ipv4.ihl,
            hdr.inner_ipv4.dscp,
            hdr.inner_ipv4.ecn,
            hdr.inner_ipv4.total_len,
            hdr.inner_ipv4.identification,
            hdr.inner_ipv4.flags,
            hdr.inner_ipv4.frag_offset,
            hdr.inner_ipv4.ttl,
            hdr.inner_ipv4.protocol,
            hdr.inner_ipv4.src_addr,
            hdr.inner_ipv4.dst_addr});
        
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.vxlan);
        pkt.emit(hdr.inner_ethernet);
        pkt.emit(hdr.inner_ipv4);

            }
}


// -------------------------EGRESS-------------------

struct shc_egress_metadata_t {

}
//egress parser
parser ShcEgressParser(
        packet_in pkt,
        out shc_header_t hdr,
        out shc_egress_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md){

    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }

}


control ShcEgress(
    /* User */
    inout shc_header_t                              hdr,
    inout shc_egress_metadata_t                     eg_meta,
    /* Intrinsic */    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md)
{
    apply{

    }
}


//egress deparser
control ShcEgressDeparser(
        packet_out pkt,
        inout shc_header_t hdr,
        in shc_egress_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr){

    apply{

    }
}

Pipeline(ShcIngressParser(),
        ShcIngress(),
        ShcIngressDeparser(),
        ShcEgressParser(),
        ShcEgress(),
        ShcEgressDeparser()) pipe;

Switch(pipe) main;