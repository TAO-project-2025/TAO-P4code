
#include <iostream>
#include <cstring>
#include <pcap.h>
#include <vector>
#include <iomanip>
#include <netinet/if_ether.h>

#include <functional>

#include "test.hpp"

// using namespace std;
uint32_t ip_n = 0;
std::hash<uint32_t> hasher;

void drv_cuckoo_get(hal_route_key key1, uint32_t *drv_cuckoo){
    hal_route_data data1 = {.nhop_id=0};

    std::size_t h1 = hasher(key1.ip_src_addr);
    std::size_t h2 = hasher(key1.ip_dst_addr);
    uint32_t offset = h1 ^ h2;
    // std::cout<<"offset: "<< offset <<std::endl;

    hal_route_entry_add(&key1, &data1);
    for(int i=0;i<4;i++){ // 当前hash way的数目是4
        drv_cuckoo[i] = htonl(driver_cuckoo_hash_get[i] + ((offset >> i) & 1)) ; // 主机字节序转为网络字节序 + 在原有基础上进行随机偏移
        // std::cout<<drv_cuckoo[i]<<" = "<<htonl(driver_cuckoo_hash_get[i])<<" + "<<((offset >> i) & 1)<<std::endl;
        if(driver_cuckoo_hash_get[i] > 0xffff){
            std::cout<<"catch an error value: "<<driver_cuckoo_hash_get[i]<<std::endl;
            std::abort();
        }
    }
    hal_route_entry_del(&key1,false);

    return;
}

void processPacket(const u_char* packet, int packetLength, pcap_dumper_t* pcapDumper) {

    const struct ether_header* ethHeader;
    ethHeader = reinterpret_cast<const struct ether_header*>(packet);

    if (ntohs(ethHeader->ether_type) != ETHERTYPE_IP){
        return;
    }
    ip_n ++;

    std::vector<u_char> newPacket(packet, packet + 34); // 34 = 14 + 20

    // if(newPacket[12] != )

    int protocolOffset = 23;
    // printf("protocolOffset = %02x\n",newPacket[protocolOffset]);
    newPacket[protocolOffset] = 100; 

    uint32_t srcIP = ntohl(*(reinterpret_cast<const uint32_t*>(packet + 26)));
    uint32_t dstIP = ntohl(*(reinterpret_cast<const uint32_t*>(packet + 30)));

    // std::cout << "srcIP: " << srcIP << std::endl;
    // std::cout << "dstIP: " << dstIP << std::endl;

    hal_route_key key1={.ip_src_addr=srcIP, .ip_dst_addr=dstIP};
    uint32_t cuckoo_hashes[4]={0};

    drv_cuckoo_get(key1,cuckoo_hashes);
    
    newPacket.insert(newPacket.end(), (u_char*)cuckoo_hashes, (u_char*)cuckoo_hashes + sizeof(cuckoo_hashes));
    
    // 创建新的数据包头部
    pcap_pkthdr header;
    header.ts.tv_sec = 0;  // 设置时间戳的秒数
    header.ts.tv_usec = 0;  // 设置时间戳的微秒数
    header.caplen = newPacket.size();  // 设置捕获长度
    header.len = newPacket.size();  // 设置数据包长度

    // 打印新数据包的长度
    // std::cout << "New packet length: " << (uint32_t)newPacket.size() << " bytes" << std::endl;
    // printf("New packet length: %u\n",newPacket.size());
    // 保存当前的输出格式标志
    // std::ios_base::fmtflags originalFlags = std::cout.flags();
    // 打印新数据包的内容（16进制格式）
    // std::cout << "New packet content:" << std::endl;
    // for (size_t i = 0; i < newPacket.size(); ++i) {
    //     std::cout << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(newPacket[i]) << " ";
    //     if ((i + 1) % 16 == 0) {
    //         std::cout << std::endl;
    //     }
    // }
    // std::cout << std::endl << "--------------------" << std::endl;
    // std::cout.flags(originalFlags);
    
    pcap_dump((u_char*)pcapDumper, &header, newPacket.data());
}

void processPcapFile(const char* pcapFilePath) {
    char errbuf[PCAP_ERRBUF_SIZE];
    
    // 打开 pcap 文件
    pcap_t* pcapHandle = pcap_open_offline(pcapFilePath, errbuf);
    if (pcapHandle == nullptr) {
        std::cerr << "Error opening pcap file: " << errbuf << std::endl;
        return;
    }

    // 创建新的 pcap 文件
    pcap_dumper_t* pcapDumper = pcap_dump_open(pcapHandle, "/share_test/pcap_files/202207251400_ip_only_add_cuckoo.pcap");
    if (pcapDumper == nullptr) {
        std::cerr << "Error creating output pcap file" << std::endl;
        pcap_close(pcapHandle);
        return;
    }
    
    // 逐个处理数据包
    struct pcap_pkthdr* header;
    const u_char* packet;
    int i = 0;
    while (pcap_next_ex(pcapHandle, &header, &packet) == 1) {
        // printf("header->len = %u\n",header->caplen);
        processPacket(packet, header->caplen, pcapDumper);
        i++;
        // if(i == 5) break;
        if(i%1000000 == 0) std::cout<<"i = "<<i<<std::endl;
    }
    std::cout<<"i = "<<i<<std::endl;
    std::cout<<"ip_n = "<<ip_n<<std::endl;
    
    // 关闭 pcap 文件
    pcap_dump_close(pcapDumper);
    pcap_close(pcapHandle);
}

void pkt_add_cuckoo(){
    cuckoo_hash_get_flag = true;
    const char* pcapFilePath = "/share_test/pcap_files/202207251400_ip_only.pcap";
    processPcapFile(pcapFilePath);
    cuckoo_hash_get_flag = false;
}
