#pragma once

#include "hal_table_api.h"
#include "hal.hpp"

#include <ctime>
#include <iostream>
#include <immintrin.h>
#include <cstdio>
#include <fstream>
#include <arpa/inet.h>

void test_route(std::shared_ptr<bfrt::BfRtSession>& session);
void pkt_add_cuckoo();
