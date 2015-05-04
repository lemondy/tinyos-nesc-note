#ifndef BEACON_H
#define BEACON_H 
#define HELLO_NEIGHBOOR 10
enum {
  AM_BEACON = 6,
  CACHE_SIZE = 200,
  INVALIDATE_NODE_ID = 0xff,
  STOP = 0x1010,    //when the dest receive the packet, stop the neighboor broadcast packet.
  HELLO = 0xaaaa,
  NEIGHBOOR_SIZE = 20
};

typedef nx_struct BeaconMsg {
  nx_uint16_t nodeidi;
  nx_uint16_t nodeidk;
  nx_uint16_t serialnumber;
} BeaconMsg;

typedef nx_struct {
	nx_uint16_t stop;
}stop_bcast;

typedef nx_struct{
	nx_uint16_t hello;
} send_hello;

typedef struct {
	am_addr_t neighboor;
} neighboor_node_table;
#endif
