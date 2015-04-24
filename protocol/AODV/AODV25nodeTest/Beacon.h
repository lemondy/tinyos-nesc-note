#ifndef BEACON_H
#define BEACON_H 

enum {
  AM_BEACON = 6
};

typedef nx_struct BeaconMsg {
  nx_uint16_t nodeidi;
  nx_uint16_t nodeidk;
  nx_uint16_t serialnumber;
} BeaconMsg;


#endif
