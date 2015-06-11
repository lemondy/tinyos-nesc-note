#ifndef BEACON_H
#define BEACON_H 

enum {
  AM_BEACON = 6,
  CACHE_SIZE = 200,
  INVALIDATE_NODE_ID = 0xffff
};

typedef nx_struct BeaconMsg {
  nx_uint16_t nodeidi;
  nx_uint16_t nodeidk;
  nx_uint16_t serialnumber;
} BeaconMsg;



typedef nx_struct {
  nx_uint16_t nodeidi;
  nx_uint16_t nodeidk;
  nx_uint16_t serialnumber;
  nx_uint8_t  hops;
} NewBeaconMsg;
#endif
