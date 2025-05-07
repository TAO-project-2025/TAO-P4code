/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;
typedef bit<24> vni_t;

const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<48> FAKE_SRC_MAC = 0x112233445566;
const int NEXTHOP_ID_WIDTH = 17;
typedef bit<(NEXTHOP_ID_WIDTH)> nexthop_id_t;

const int NEXTHOP_TABLE_SIZE   = 1 << NEXTHOP_ID_WIDTH;

const bit<3> FK_LEARN_DIGEST = 1;
const bit<3> FK_FLOW_DIGEST = 2;

const bit<15> PAD = 0;

header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

header ipv4_h {
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

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length;
    bit<16> checksum;
}

header tcp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<32>  seq_no;
    bit<32>  ack_no;
    bit<4>   data_offset;
    bit<4>   res;
    bit<8>   flags;
    bit<16>  window;
    bit<16>  checksum;
    bit<16>  urgent_ptr;
}

header vxlan_h {
    bit<8> flags;
    bit<24> reserved;
    bit<24> vni;
    bit<8> reserved2;
}

struct shc_header_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    udp_h udp;
    tcp_h tcp;
    vxlan_h vxlan;
    ethernet_h inner_ethernet;
    ipv4_h inner_ipv4;  
}

struct encap_info_t {

    // bit<32> nhop_id;
    // bit<24> vni;
    // bit<32> srcip;
    // bit<32> dstip;
    bit<32> neigh_id;
    bit<16> port;

}

struct shc_ingress_metadata_t {
    // for sketch
    bit<24> vni;
    bit<64> SDIP;
    bit<32> src_addr;
    bit<32> dst_addr;
    bit<16> src_port;
    bit<16> dst_port;
    bit<8>  protocol;


    bit<32> pkt_n_c;
    bit<1>  pkt_n_done_flag; 

    bit<17> hash_value1;
    bit<16> hash_value2;
    bit<16> hash_pkt1;
    bit<16> hash_pkt2;
    bit<1>  hash_pkt1_tmp;
    bit<8> hash_pkt1_num;
    bit<1> hash_pkt1_done;

    bit<16> hash_cond1; //概率
    bit<16> rnd1;
    bit<1> cond_rnd_flag1;

    // 输出参数
    bit<1> eflag;

    // for digest
    bit<1> type_for_digest; 
    PortId_t port;
    bit<48> time_stamp;

    // for route
    bit<1> type;
    bit<16> vrf;
    bit<32> nhop_id;

    encap_info_t meta;


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
        // ig_md.vni = 1;
        ig_md.src_addr = hdr.ipv4.src_addr;
        ig_md.dst_addr = hdr.ipv4.dst_addr;
        // ig_md.SDIP = hdr.ipv4.src_addr ++ hdr.ipv4.dst_addr;
        // ig_md.protocol = hdr.ipv4.protocol;
        transition select(hdr.ipv4.protocol) {
            17 :  parse_udp;
            6 :   parse_tcp;
            default: accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        // ig_md.src_port = hdr.udp.src_port;
        // ig_md.dst_port = hdr.udp.dst_port;
        
        transition select(hdr.udp.dst_port) {
            4789 : parse_vxlan;
            default : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        // ig_md.src_port = hdr.tcp.src_port;
        // ig_md.dst_port = hdr.tcp.dst_port;
        transition accept;
    }

    state parse_vxlan {
        pkt.extract(hdr.vxlan);
        // ig_md.vni = hdr.vxlan.vni;
        // ig_md.type = 1;
        // ig_md.eflag = 0;
        // ig_md.vrf = 0;
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
    Register<bit<32>,bit<1>>(1,0) pkt_num;
    RegisterAction<bit<32>,bit<1>,bit<32>>(pkt_num) pkt_num_count={
		void apply(inout bit<32> register_data, out bit<32> pkt_n){
            register_data = register_data + 1;
            pkt_n = register_data;

            // if(register_data == 9){ //if中大小比较的常数不能超过12bit，等于== 无限制 //将65535改成100，方便功能测试
            //     register_data = 3;
            // }
            // else{
            //     register_data = register_data + 1;
            // }
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

    // /* CRC32  as crc32_1*/
    // CRCPolynomial<bit<64>>(coeff=0x04C11DB7,reversed=true, msb=false, extended=false, init=0xFFFFFFFF, xor=0xFFFFFFFF) crc32_1;
    // CRCPolynomial<bit<64>>(coeff=0x1EDC6F41,reversed=true, msb=false, extended=false, init=0xFFFFFFFF, xor=0xFFFFFFFF) crc32_2;
    
     // Hash<bit<17>>(HashAlgorithm_t.RANDOM) hash1;
    Hash<bit<17>>(HashAlgorithm_t.RANDOM) hash1; //pucket
    Hash<bit<16>>(HashAlgorithm_t.CRC16) hash2; //fingerprint

    action get_hash_value1(){
        // ig_md.hash_value1 = hash1.get({ig_md.vni, ig_md.src_addr, ig_md.dst_addr});
        // ig_md.hash_value1 = hash1.get({ig_md.SDIP}); //for test 
        ig_md.hash_value1 = hash1.get({ig_md.src_addr, ig_md.dst_addr}); //for test
        // ig_md.hash_value2 = (bit<16>)hash2.get({ig_md.src_addr, ig_md.dst_addr, ig_md.protocol, ig_md.src_port,ig_md.dst_port});
    }
    // 一个表中操作多个hash时，只能操作和小于32bit的hash，若大于32bit需要拆分成多个表来计算hash
    table get_hash_value1_table{ 
        actions = {
            get_hash_value1;
        }
        size = 1;
        default_action = get_hash_value1();
    }
    action get_hash_value2(){
        // ig_md.hash_value1 = hash1.get({ig_md.vni, ig_md.src_addr, ig_md.dst_addr});
        // ig_md.hash_value1 = (bit<17>)hash1.get({ig_md.src_addr, ig_md.dst_addr, ig_md.protocol, ig_md.src_port,ig_md.dst_port}); //for test
        // ig_md.hash_value2 = hash2.get({ig_md.SDIP});
        ig_md.hash_value2 = hash2.get({ig_md.src_addr, ig_md.dst_addr}); //直接~ig_md.dst_addr, 会导致bfrt_python打不开
    }
    table get_hash_value2_table{ 
        actions = {
            get_hash_value2;
        }
        size = 1;
        default_action = get_hash_value2();
    }
    
    //hash1_1 35 * 2^7 *2^10  32 * 2^10 * 2^7
    Register<bit<16>,bit<17>>(1<<17) hash1_1;
    RegisterAction<bit<16>,bit<17>,bit<1>>(hash1_1) pkt_update_1={
		void apply(inout bit<16> register_data, out bit<1> pkt_num_o){
            if(ig_md.hash_value2 == register_data){
                pkt_num_o = 1;
            }
            else{
                pkt_num_o = 0;
                register_data = ig_md.hash_value2;
            }
            // pkt_num_o = register_data;
		}
	};
    action update_pkt_1(){
        // ig_md.hash_pkt1_tmp = pkt_update_1.execute(0);
        ig_md.hash_pkt1_tmp = pkt_update_1.execute(ig_md.hash_value1);
        ig_md.hash_pkt1_done = 1;
    }    
    table update_pkt_1_table{
        actions = {
            update_pkt_1;
        }
        size = 1;
        default_action = update_pkt_1();
    }
    //register 中register_data赋值不能超过2次
    Register<bit<8>,bit<17>>(1<<17,1) hash1_1_n;
    RegisterAction<bit<8>,bit<17>,bit<8>>(hash1_1_n) pkt_num_1={
		void apply(inout bit<8> register_data, out bit<8> pkt_num_e){
            if(ig_md.hash_pkt1_tmp == 1 && register_data < 1){
                register_data = register_data + 1;
            }
            else{
                register_data = 1;
            }
            pkt_num_e = register_data;
            // register_data = ig_md.hash_value2;
		}
	};
    action update_pkt_num_1(){
        ig_md.hash_pkt1_num = pkt_num_1.execute(ig_md.hash_value1);
        // ig_md.hash_pkt1_num = pkt_num_1.execute(0);
    }    
    table update_pkt_num_1_table{
        actions = {
            update_pkt_num_1;
        }
        size = 1;
        default_action = update_pkt_num_1();
    }


    Random<bit<16>>() random_generator;
	action generate_random_number1(){
		ig_md.rnd1 = random_generator.get();
	}
    // action calc_cond1(){
    //     ig_md.hash_cond1 = prog_64K_div_x.execute(0);
    // }
    action cond_rnd1(){
        generate_random_number1();
        // calc_cond1();
        ig_md.cond_rnd_flag1 = 1;
    }
	table cond_rnd1_table{ //根据最小的size(ig_md.hash_size)计算概率值，并生成随机数，进行饱和减
        actions = {
			cond_rnd1;
		}
		size = 1;
		default_action = cond_rnd1();
	}

    action cond_rnd_m(){
        ig_md.hash_cond1 = 3277 |-| ig_md.rnd1; // 1% 6554,50% 32768, 0.1% 66
    }
    table cond_rnd_m_table{
        actions = {
			cond_rnd_m;
		}
		size = 1;
		default_action = cond_rnd_m();
    }

    apply {
        // ig_md.SDIP = ig_md.src_addr ++ ig_md.dst_addr; //使用这种方式，hash冲突太严重
        // count_pkt_num_table.apply();

        // if(ig_md.pkt_n_done_flag >= 0){
        // ig_md.dst_addr = ~ig_md.dst_addr;
        cond_rnd1_table.apply();
        if(ig_md.cond_rnd_flag1 == 1){
            cond_rnd_m_table.apply();

            if(ig_md.hash_cond1 > 0){ //for test =0
                get_hash_value1_table.apply(); // 0
                get_hash_value2_table.apply();
                update_pkt_1_table.apply(); // 
                // update_pkt_2_table.apply(); // 1
                if(ig_md.hash_pkt1_done == 1){
                    update_pkt_num_1_table.apply();
                    ig_md.pkt_n_c = pkt_num_count.execute(0);
                    if(ig_md.hash_pkt1_num == 1){
                        ig_md.eflag = 1;
                    }
                    else{
                        ig_md.eflag = 0;
                    }
                }
                
            }
        }
    // }
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

    Register<bit<32>,bit<1>>(1,0) pkt_num_0;
    RegisterAction<bit<32>,bit<1>,bit<32>>(pkt_num_0) pkt_num_count_0={
		void apply(inout bit<32> register_data){
            register_data = register_data + 1;
            // pkt_n = register_data;

            // if(register_data == 9){ //if中大小比较的常数不能超过12bit，等于== 无限制 //将65535改成100，方便功能测试
            //     register_data = 3;
            // }
            // else{
            //     register_data = register_data + 1;
            // }
		}
	};

    action tunnel_map_vrf(bit<16> vrf){
        ig_md.vrf = vrf;
    }
    table tunnel_map_vrf_tbl{
        key = {
            ig_md.type : exact;
            hdr.vxlan.vni : exact;
        }
        actions = {
            tunnel_map_vrf;
            NoAction;
        }
        const default_action = NoAction;
        size = 8192;
    }

    action route_for_nexthop(bit<32> nhop_id){
        ig_md.nhop_id = nhop_id;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;

        ig_md.port = ig_intr_md.ingress_port;
        ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
        ig_md.type_for_digest = 1;
        ig_md.time_stamp = ig_intr_md.ingress_mac_tstamp;
    }
    // action route_for_miss(){
    //     ig_tm_md.ucast_egress_port = 16;
    //     ig_tm_md.bypass_egress = 1;
    //     ig_md.type_for_digest = 0;
    //     // ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
    //     ig_md.time_stamp = 0;
    // }
    table route_tbl{
        key = {
            ig_md.vrf : exact;
            hdr.inner_ipv4.src_addr : exact;
            hdr.inner_ipv4.dst_addr : exact;
        }
        actions = {
            route_for_nexthop;
            // route_for_miss;
            NoAction;
        }
        const default_action = NoAction;
        size = 65535;
    }

//for route selector
    action route_sele_for_nexthop(bit<32> nhop_id){
        ig_md.nhop_id = nhop_id;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;

        ig_md.port = ig_intr_md.ingress_port;
        ig_tm_md.bypass_egress = 0;
        // ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
        ig_md.type_for_digest = 1;
        ig_md.time_stamp = ig_intr_md.ingress_mac_tstamp;
    }
    action route_sele_for_miss(){
        ig_tm_md.ucast_egress_port = 65;
        ig_tm_md.bypass_egress = 1;
        ig_md.type_for_digest = 0;
        // ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
        ig_md.time_stamp = 0;
    }

    @idletime_precision(2)
    table route_sele_tbl{
        key = {
            // ig_md.vrf : exact;
            // hdr.ipv4.protocol : exact;
            hdr.ipv4.src_addr : exact;
            hdr.ipv4.dst_addr : exact;
            // hdr.ipv4.dst_addr : ternary;
            // ig_md.src_port : exact;
            // ig_md.dst_port : exact;
        }
        actions = {
            route_sele_for_nexthop;
            route_sele_for_miss;
        }
        const default_action = route_sele_for_miss();
        size = 200000;
        idle_timeout = true;
    }


//encap vxlan
    action nhop(bit<24> vni, bit<32> local, bit<32> remote,bit<32> neigh_id){
        hdr.vxlan.vni = vni;
        hdr.ipv4.src_addr = local;
        hdr.ipv4.dst_addr = remote;
        ig_md.meta.neigh_id = neigh_id;
    }
    table nhop_tbl{
        key = {
            ig_md.nhop_id : exact;           
        }
        actions = {
            nhop;
            NoAction;
        }
        const default_action = NoAction;
        size = 65535;
    }

    action neigh(bit<48> dmac){
        hdr.inner_ethernet.dst_addr = dmac;
        hdr.inner_ethernet.src_addr = FAKE_SRC_MAC;
    }
    table neigh_tbl{
        key = {
            ig_md.meta.neigh_id : exact;           
        }
        actions = {
            neigh;
            NoAction;
        }
        const default_action = NoAction;
        size = 1024;
    }

    action port_for_mac(bit<48> smac, bit<48> dmac){
        hdr.ethernet.dst_addr = dmac;
        hdr.ethernet.src_addr = smac;
    }
    action fake_mac_for_outer(){
        hdr.ethernet.dst_addr = 0x112233445577;
        hdr.ethernet.src_addr = 0x112233445588;
    }
    table port_for_mac_tbl{
        key = {
            ig_md.meta.port : exact;
        }
        actions = {
            port_for_mac;
            fake_mac_for_outer;
        }
        const default_action = fake_mac_for_outer;
        size = 512;
    }
    
    apply{
        
        // if (hdr.vxlan.isValid() && hdr.inner_ipv4.isValid()) { 
        // if (hdr.ipv4.isValid() && (hdr.udp.isValid() || hdr.tcp.isValid())) { 
           if (hdr.ipv4.isValid()) { 
            pkt_num_count_0.execute(0);
            tunnel_map_vrf_tbl.apply();
            if(route_tbl.apply().hit){
                nhop_tbl.apply();
                neigh_tbl.apply();
                port_for_mac_tbl.apply(); 
            }
            else{
                sk.apply(ig_md);
                if(ig_md.eflag == 1){
                    ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
                }
                else{
                    ig_dprsr_md.digest_type = 0;
                }
                // route_sele_tbl.apply();
                if(route_sele_tbl.apply().miss){ // digest only miss 
                    // if(ig_md.eflag == 1){
                    //     ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
                    // }
                    // else{
                    //     ig_dprsr_md.digest_type = 0;
                    // }
                }
                else{
                    nhop_tbl.apply();
                    neigh_tbl.apply();
                    port_for_mac_tbl.apply(); 
                }

                // route_sele_tbl.apply();
                // sk.apply(ig_md);
                // if(ig_tm_md.bypass_egress == 1){
                //     if(ig_md.eflag == 1){
                //         ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
                //     }
                //     else{
                //         ig_dprsr_md.digest_type = 0;
                //     }
                // }
                // else{
                //     nhop_tbl.apply();
                //     neigh_tbl.apply();
                //     port_for_mac_tbl.apply(); 
                // }
            }
        }
    }
}
// 当使用两个digest时，会出现32bit container Consecutive location 的错误，应该是巧合
// 由于PortId_t为16bit，与后面的bit<16> vrf_digest 凑成一个32bit，编译器会将两个16bit放在同一个32bit container里面，导致出错

struct flowkey_digest_t {
    // PortId_t port;
    bit<1>  type;
    // bit<24> vni_digest;
    bit<32> src_ip_digest;
    bit<32> dst_ip_digest;
    // bit<16> src_port;
    // bit<16> dst_port;
    // bit<8>  protocol;

    // bit<48> time_stamp;
    bit<32> count;

}

//ingress deparser
control ShcIngressDeparser(
    packet_out pkt,
    inout shc_header_t hdr,
    in shc_ingress_metadata_t ig_md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md){

    Digest<flowkey_digest_t>() flowkey_digest;

    Checksum() ipv4_checksum;
    // Checksum() inner_ipv4_checksum;

    apply {
        if(ig_dprsr_md.digest_type == FK_LEARN_DIGEST){
            flowkey_digest.pack({
                // ig_md.port,
                ig_md.type_for_digest,
                // ig_md.vni,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                // ig_md.src_port,
                // ig_md.dst_port,
                // ig_md.protocol,
                // ig_md.time_stamp
                ig_md.pkt_n_c
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

        
        // hdr.inner_ipv4.hdr_checksum = inner_ipv4_checksum.update({
        //     hdr.inner_ipv4.version,
        //     hdr.inner_ipv4.ihl,
        //     hdr.inner_ipv4.dscp,
        //     hdr.inner_ipv4.ecn,
        //     hdr.inner_ipv4.total_len,
        //     hdr.inner_ipv4.identification,
        //     hdr.inner_ipv4.flags,
        //     hdr.inner_ipv4.frag_offset,
        //     hdr.inner_ipv4.ttl,
        //     hdr.inner_ipv4.protocol,
        //     hdr.inner_ipv4.src_addr,
        //     hdr.inner_ipv4.dst_addr});
        
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.tcp);
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