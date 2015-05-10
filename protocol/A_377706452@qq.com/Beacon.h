#ifndef BEACON_H
#define BEACON_H 

#define HELLO_NEIGHBOOR 10
enum {
  AM_BEACON = 6,
  CACHE_SIZE = 200,
  INVALIDATE_NODE_ID = 0xff,
  STOP = 0x1010,    
  NEIGHBOOR_SIZE = 20,
  QUEUE_SIZE = 50,
  HOP = 4,
  HELLO = 0xaa
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
	uint16_t neighboor;
} neighboor_node_table;

#endif
