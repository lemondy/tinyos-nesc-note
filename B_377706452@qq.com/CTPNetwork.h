#ifndef CTP_NETWORK_H
#define CTP_NETWORK_H

#include <AM.h>

enum {
 COLLECTION_ID = 0xEE,
 AM_BEACON = 6,
};

typedef nx_struct CTPNetworkMsg {
  nx_uint16_t nodeid;
  nx_uint8_t  data[28];
} CTPNetworkMsg_t;

#endif
