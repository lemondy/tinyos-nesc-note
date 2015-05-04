#ifndef BEACON_H
#define BEACON_H 

enum {
  AM_BEACON = 6,
  CACHE_SIZE = 200,
  INVALIDATE_NODE_ID = 0xff,
  STOP = 0x1010
};

typedef nx_struct BeaconMsg {
  nx_uint16_t nodeidi;
  nx_uint16_t nodeidk;
  nx_uint16_t serialnumber;
} BeaconMsg;

typedef nx_struct {
	nx_uint16_t stop;
}stop_bcast;

#endif
