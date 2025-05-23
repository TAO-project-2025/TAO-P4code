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
    vxlan_h vxlan;
    ethernet_h inner_ethernet;
    ipv4_h inner_ipv4;  
}

struct ip_pair_t {
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
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
    bit<16> hash_value1;
    bit<16> hash_value2;
    bit<16> hash_pkt1;
    bit<16> hash_pkt2;

    bit<1>  hash_pkt1_done_flag; 
    bit<1>  hash_pkt2_done_flag; 

    bit<16> hash_cond1; //概率
    bit<16> hash_cond2; //概率
    bit<16> rnd1;
    bit<16> rnd2;

    bit<32> vni;
    bit<32> src_addr;
    bit<32> dst_addr;

    bit<1> cond_rnd_flag1;
    bit<1> cond_rnd_flag2;

    bit<1> type;
    bit<16> vrf;
    bit<32> nhop_id;
    
    // 输出参数
    bit<1> replace_flag; //key不同是否概率更改

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
        transition select(hdr.ipv4.protocol) {
            17 :  parse_udp;

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

    state parse_vxlan {
        pkt.extract(hdr.vxlan);
        ig_md.vni = (bit<32>)hdr.vxlan.vni;
        ig_md.type = 1;
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
        ig_md.src_addr = hdr.inner_ipv4.src_addr;
        ig_md.dst_addr = hdr.inner_ipv4.dst_addr;

        transition accept;
    }

}

// sketch 
control Sketch(//in shc_header_t hdr, // 定义为hdr 若定义为in bit<16> len编译无错，执行时会报错
               inout shc_ingress_metadata_t ig_md)()
{
    /* CRC32  as crc32_1*/
    CRCPolynomial<bit<32>>(coeff=0x04C11DB7,reversed=true, msb=false, extended=false, init=0xFFFFFFFF, xor=0xFFFFFFFF) crc32_1;
    CRCPolynomial<bit<32>>(coeff=0x1EDC6F41,reversed=true, msb=false, extended=false, init=0xFFFFFFFF, xor=0xFFFFFFFF) crc32_2;
    
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc32_1) hash1;
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc32_2) hash2;

    action get_hash_value(){
        ig_md.hash_value1 = hash1.get({ig_md.vni, ig_md.src_addr, ig_md.dst_addr});
        ig_md.hash_value2 = hash2.get({ig_md.vni, ig_md.src_addr, ig_md.dst_addr});
    }
    table get_hash_value_table{ 
        actions = {
            get_hash_value;
        }
        size = 1;
        default_action = get_hash_value();
    }
    
    //hash1_1 35 * 2^7 *2^10  32 * 2^10 * 2^7
    Register<bit<32>,bit<17>>(130000) hash1_1;
    RegisterAction<bit<16>,bit<16>,bit<16>>(hash1_1) pkt_update_1={
		void apply(inout bit<16> register_data, out bit<16> pkt_num){
            if(register_data == 65535){ //if中大小比较的常数不能超过12bit，等于== 无限制
                register_data = 1;
            }
            else{
                register_data = register_data + 1;
            }
            pkt_num = register_data;
		}
	};
    action update_pkt_1(){
        ig_md.hash_pkt1 = pkt_update_1.execute(ig_md.hash_value1);
        ig_md.hash_pkt1_done_flag = 1;
    }    
    table update_pkt_1_table{
        actions = {
            update_pkt_1;
        }
        size = 1;
        default_action = update_pkt_1();
    }

    // hash2_1
    Register<bit<32>,bit<17>>(130000) hash2_1;
    RegisterAction<bit<16>,bit<16>,bit<16>>(hash2_1) pkt_update_2={ //register 内不能多次赋值
		void apply(inout bit<16> register_data, out bit<16> pkt_num){
            if(register_data == 65535){
                register_data = 1;
            }
            else{
                register_data = register_data + 1;
            }
            pkt_num = register_data;
		}
	};
    action update_pkt_2(){
        ig_md.hash_pkt2 = pkt_update_2.execute(ig_md.hash_value2);
        ig_md.hash_pkt2_done_flag = 1;
    }    
    table update_pkt_2_table{
        actions = {
            update_pkt_2;
        }
        size = 1;
        default_action = update_pkt_2();
    }
    
    //hash1_3
    Register<bit<32>,bit<16>>(65536) hash1_3;
    RegisterAction<bit<32>,bit<16>,bit<1>>(hash1_3) vni_update_1={
		void apply(inout bit<32> register_data){
            register_data = ig_md.vni;
		}
	};

    action update_vni_1(){
        vni_update_1.execute(ig_md.hash_value1);
    }
    table update_vni_1_table{
        actions = {
            update_vni_1;
        }
        size = 1;
        default_action = update_vni_1();
    }

    //hash2_3
    Register<bit<32>,bit<16>>(65536) hash2_3;
    RegisterAction<bit<32>,bit<16>,bit<1>>(hash2_3) vni_update_2={
		void apply(inout bit<32> register_data){
            register_data = ig_md.vni;
		}
	};

    action update_vni_2(){
        vni_update_2.execute(ig_md.hash_value2);
    }
    table update_vni_2_table{
        actions = {
            update_vni_2;
        }
        size = 1;
        default_action = update_vni_2();
    }

    //hash1_2
    Register<ip_pair_t,bit<16>>(65536) hash1_2;
    RegisterAction<ip_pair_t,bit<16>,bit<1>>(hash1_2) ip_update_1={
		void apply(inout ip_pair_t register_data){
            register_data.dst_addr = ig_md.dst_addr;
            register_data.src_addr = ig_md.src_addr;
		}
	};

    action update_ip_1(){
        ip_update_1.execute(ig_md.hash_value1);
    }
    table update_ip_1_table{
        actions = {
            update_ip_1;
        }
        size = 1;
        const default_action = update_ip_1();
    }

    //hash2_2
    Register<ip_pair_t,bit<16>>(65536) hash2_2;
    RegisterAction<ip_pair_t,bit<16>,bit<1>>(hash2_2) ip_update_2={
		void apply(inout ip_pair_t register_data){
            register_data.dst_addr = ig_md.dst_addr;
            register_data.src_addr = ig_md.src_addr;
		}
	};

    action update_ip_2(){
        ip_update_2.execute(ig_md.hash_value2);
    }
    table update_ip_2_table{
        actions = {
            update_ip_2;
        }
        size = 1;
        const default_action = update_ip_2();
    }

    Register<bit<16>,bit<1>>(1) num_32;
	MathUnit<bit<16>>(true,0,9,{68,73,78,85,93,102,113,128,0,0,0,0,0,0,0,0}) prog_64K_div_mu;
	RegisterAction<bit<16>,bit<1>,bit<16>>(num_32) prog_64K_div_x = {
		void apply(inout bit<16> register_data, out bit<16> mau_value){
            register_data = prog_64K_div_mu.execute(ig_md.hash_pkt1);
			mau_value = register_data; 
		}
	};

    Register<bit<16>,bit<1>>(1) num_32_t;
	MathUnit<bit<16>>(true,0,9,{68,73,78,85,93,102,113,128,0,0,0,0,0,0,0,0}) prog_64K_div_mu_t;
	RegisterAction<bit<16>,bit<1>,bit<16>>(num_32_t) prog_64K_div_x_t = {
		void apply(inout bit<16> register_data, out bit<16> mau_value){
            register_data = prog_64K_div_mu.execute(ig_md.hash_pkt2);
			mau_value = register_data; 
		}
	};

    Random<bit<16>>() random_generator;
	action generate_random_number1(){
		ig_md.rnd1 = random_generator.get();
	}
    action calc_cond1(){
        ig_md.hash_cond1 = prog_64K_div_x.execute(0);
    }
    action cond_rnd1(){
        generate_random_number1();
        calc_cond1();
        ig_md.cond_rnd_flag1 = 1;
    }
	table cond_rnd1_table{ //根据最小的size(ig_md.hash_size)计算概率值，并生成随机数，进行饱和减
        actions = {
			cond_rnd1;
		}
		size = 1;
		default_action = cond_rnd1();
	}

    action generate_random_number2(){
        ig_md.rnd2 = random_generator.get();
	}
    action calc_cond2(){
        ig_md.hash_cond2 = prog_64K_div_x_t.execute(0);
    }
    action cond_rnd2(){
        generate_random_number2();
        calc_cond2();
        ig_md.cond_rnd_flag2 = 1;
    }
	table cond_rnd2_table{ //根据最小的size(ig_md.hash_size)计算概率值，并生成随机数，进行饱和减
        actions = {
			cond_rnd2;
		}
		size = 1;
		default_action = cond_rnd2();
	}

    action cond_rnd_m(){
        ig_md.hash_cond1 = ig_md.hash_cond1 |-| ig_md.rnd1;
        ig_md.hash_cond2 = ig_md.hash_cond2 |-| ig_md.rnd2;
    }
    table cond_rnd_m_table{
        actions = {
			cond_rnd_m;
		}
		size = 1;
		default_action = cond_rnd_m();
    }

    apply {
        get_hash_value_table.apply(); // 0
        update_pkt_1_table.apply(); // 
        update_pkt_2_table.apply(); // 1

        if(ig_md.hash_pkt1_done_flag == 1){ //flag条件不能合在一起，每一个操作mathunit的表都需要有自己匹配条件，即key。必须是match依赖
            cond_rnd1_table.apply(); // 使用 mathunit1 
            if(ig_md.hash_pkt2_done_flag == 1){
                cond_rnd2_table.apply(); // 使用 mathunit2
            }
        }
        // if(ig_md.hash_pkt2_done_flag == 1){
        //     cond_rnd2_table.apply(); // 使用 mathunit2
        // }

        // if(ig_md.cond_rnd_flag1 == 1 && ig_md.cond_rnd_flag2 == 1){
            cond_rnd_m_table.apply(); // 44
            if(ig_md.hash_cond1 > 0 || ig_md.hash_cond2 > 0){ // 内部注释
                ig_md.replace_flag = 1; // 7
                update_ip_1_table.apply();// 66 主要问题应该是这里，注释了就没问题，如果和下面的table一起就会报错
                update_vni_1_table.apply();// 55
                update_ip_2_table.apply();// 66 主要问题应该是这里，注释了就没问题，如果和下面的table一起就会报错
                update_vni_2_table.apply();// 55
            }
            else{
                ig_md.replace_flag = 0;
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
        size = 8192 * 2;
    }

    action route_for_nexthop(bit<32> nhop_id){
        ig_md.nhop_id = nhop_id;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
    }
    // action fk_learn_notify() {
    //     ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
    // }
    action route_for_miss(){
        ig_tm_md.ucast_egress_port = 1;
        ig_tm_md.bypass_egress = 1;
        // ig_tm_md.copy_to_cpu = ig_md.replace_flag;
        ig_dprsr_md.digest_type = FK_LEARN_DIGEST;
    }
    @idletime_precision(3)
    table route_tbl{
        key = {
            ig_md.vrf : exact;
            hdr.inner_ipv4.src_addr : exact;
            hdr.inner_ipv4.dst_addr : exact;
        }
        actions = {
            route_for_nexthop;
            route_for_miss;
        }
        const default_action = route_for_miss();
        size = 65535 * 2;
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
        size = 65535 * 2;
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
        size = 1024 * 2;
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

        // sk.apply(ig_md);

        if (hdr.vxlan.isValid() && hdr.inner_ipv4.isValid()) { 
            tunnel_map_vrf_tbl.apply();
            route_tbl.apply();
            nhop_tbl.apply();
            neigh_tbl.apply();
            port_for_mac_tbl.apply();          
        }
    }
}

struct flowkey_digest_t {
    bit<16> vrf_digest;
    bit<32> src_ip_digest;
    bit<32> dst_ip_digest;
}

//ingress deparser
control ShcIngressDeparser(
    packet_out pkt,
    inout shc_header_t hdr,
    in shc_ingress_metadata_t ig_md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md){

    Digest <flowkey_digest_t>() flowkey_digest;

    Checksum() ipv4_checksum;
    Checksum() inner_ipv4_checksum;

    apply {
        if(ig_dprsr_md.digest_type == FK_LEARN_DIGEST){
            flowkey_digest.pack({
                ig_md.vrf,
                hdr.inner_ipv4.src_addr,
                hdr.inner_ipv4.dst_addr
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

    bit<32> nhop_id;
    bit<24> vni;
    bit<32> srcip;
    bit<32> dstip;
    bit<32> neigh_id;
    bit<48> dmac;
    bit<16> port;

    bit<1> flag;

}
//egress parser
parser ShcEgressParser(
        packet_in pkt,

        out shc_header_t hdr,
        out shc_egress_metadata_t eg_md,

        out egress_intrinsic_metadata_t eg_intr_md){

    state start {
        pkt.extract(eg_intr_md);
        // pkt.advance(PORT_METADATA_SIZE);
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
        transition select(hdr.ipv4.protocol) {
            17 :  parse_udp;

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

    state parse_vxlan {
        pkt.extract(hdr.vxlan);
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
    

    // action nhop(bit<24> vni, bit<32> local, bit<32> remote,bit<16> neigh_id){
    //     hdr.vxlan.vni = vni;
    //     hdr.ipv4.src_addr = local;
    //     hdr.ipv4.dst_addr = remote;
    //     meta.neigh_id = neigh_id;
    // }
    // table nhop_tbl{
    //     key = {
    //         meta.nhop_id : exact;           
    //     }
    //     actions = {
    //         nhop;
    //         NoAction;
    //     }
    //     const default_action = NoAction;
    //     size = 65535;
    // }

    // action neigh(bit<48> dmac){
    //     hdr.inner_ethernet.dst_addr = dmac;
    // }
    // table neigh_tbl{
    //     key = {
    //         meta.neigh_id : exact;           
    //     }
    //     actions = {
    //         neigh;
    //         NoAction;
    //     }
    //     const default_action = NoAction;
    //     size = 1024;
    // }

    // action port_for_mac(bit<48> smac, bit<48> dmac){
    //     hdr.ethernet.dst_addr = dmac;
    //     hdr.ethernet.src_addr = smac;
    // }
    // table port_for_mac_tbl{
    //     key = {
    //         meta.port : exact;
    //     }
    //     actions = {
    //         port_for_mac;
    //         NoAction;
    //     }
    //     const default_action = NoAction;
    //     size = 512;
    // }

    // apply {
    //     if(hdr.ipv4.isValid()){
    //         nhop_tbl.apply();
    //         neigh_tbl.apply();
    //         port_for_mac_tbl.apply();
    //     }
    // }
    apply{

    }
}


//egress deparser
control ShcEgressDeparser(
        packet_out pkt,
        inout shc_header_t hdr,
        in shc_egress_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr){

    // Checksum() ipv4_checksum;
    // Checksum() inner_ipv4_checksum;

    // apply {
    //     hdr.ipv4.hdr_checksum = ipv4_checksum.update({
    //         hdr.ipv4.version,
    //         hdr.ipv4.ihl,
    //         hdr.ipv4.dscp,
    //         hdr.ipv4.ecn,
    //         hdr.ipv4.total_len,
    //         hdr.ipv4.identification,
    //         hdr.ipv4.flags,
    //         hdr.ipv4.frag_offset,
    //         hdr.ipv4.ttl,
    //         hdr.ipv4.protocol,
    //         hdr.ipv4.src_addr,
    //         hdr.ipv4.dst_addr});

        
    //     hdr.inner_ipv4.hdr_checksum = inner_ipv4_checksum.update({
    //         hdr.inner_ipv4.version,
    //         hdr.inner_ipv4.ihl,
    //         hdr.inner_ipv4.dscp,
    //         hdr.inner_ipv4.ecn,
    //         hdr.inner_ipv4.total_len,
    //         hdr.inner_ipv4.identification,
    //         hdr.inner_ipv4.flags,
    //         hdr.inner_ipv4.frag_offset,
    //         hdr.inner_ipv4.ttl,
    //         hdr.inner_ipv4.protocol,
    //         hdr.inner_ipv4.src_addr,
    //         hdr.inner_ipv4.dst_addr});
        
    //     pkt.emit(hdr.ethernet);
    //     pkt.emit(hdr.ipv4);
    //     pkt.emit(hdr.udp);
    //     pkt.emit(hdr.vxlan);
    //     pkt.emit(hdr.inner_ethernet);
    //     pkt.emit(hdr.inner_ipv4);

    // }
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