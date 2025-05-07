#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include<map>
#include<iostream>
#include<fstream>
#include<algorithm>
#include<math.h>
#include<netinet/in.h>
#include<sys/socket.h>
#include<arpa/inet.h>
#include<unistd.h>
#include<set>

using namespace std;

struct pt_t
{
    uint32_t pkt;
    uint32_t stime;
    // bool operator< (const sort_node_t &rhs) const{
    //     return count < rhs.count;
    // }
};

int main(){
    int i=0;
    map<string,pt_t> rules;
    ifstream file;
    string a,flowid;
    uint32_t pkts=0,st=0,et;
    int len=0,pos=0,pos1=0,num_of_flows=0,num_of_rules=0; //pos records the first blank and pos1 records the second blank
    file.open("./../active_flowset.txt");
    if(!file) cout<<"open cs file failed!"<<endl;
    while(getline(file,a)){
        pos = a.find_last_of(",");
        flowid = a.substr(0,pos);

        if(rules.find(flowid) != rules.end()){ //find
            rules[flowid].pkt += pkts;
            if(rules[flowid].stime > st)
                rules[flowid].stime = st;
        }
        else{
            rules[flowid].pkt = pkts;
            rules[flowid].stime = st;
        }
        len += pkts;
        num_of_rules ++;
    }
    freopen("./active_flowset_aggregated.txt","w",stdout);
    for(auto iter=rules.begin();iter!=rules.end();iter++){
        num_of_flows++;
        cout<<iter->first<<endl;
        // cout<<iter->first<<" "<<iter->second.pkt<<" "<<iter->second.stime<<endl;
    }
    freopen("/dev/tty", "w", stdout);

    cout<<num_of_rules<<" "<<num_of_flows<<endl;

    return 0;
}