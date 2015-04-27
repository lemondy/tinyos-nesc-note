
 #ifndef PDV_H
 #define PDV_H

#define AM_PDV_HELLO         9
#define AM_PDV_RREQ          10
#define AM_PDV_RREP          11
#define AM_PDV_RERR          12
#define AM_PDV_MSG           13

enum{
  HELLO = 0xaaaa
};

typedef nx_struct{
  nx_uint8_t seq;
  nx_uint16_t hello;
  nx_am_addr_t src;
} send_hello_hdr;

typedef nx_struct{
  nx_uint8_t seq;
  nx_am_addr_t me;
} receive_hello_hdr;

typedef nx_struct {
  nx_uint8_t    seq;
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    hop;
} PDV_rreq_hdr;


typedef nx_struct {
  nx_uint8_t    seq;
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    hop;
} PDV_rrep_hdr;


typedef nx_struct {
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
} PDV_rerr_hdr;


typedef nx_struct {
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    app;
  nx_uint8_t    data[1];
} PDV_msg_hdr;


typedef struct {
  uint8_t    seq;
  am_addr_t  dest;
  am_addr_t  next;
  uint8_t    hop;
  uint8_t    ttl;
} PDV_ROUTE_TABLE;


typedef struct {
  uint8_t    seq;
  am_addr_t  dest;
  am_addr_t  src;
  uint8_t    hop;
  uint8_t    ttl;
} PDV_RREQ_CACHE;


#define PDV_HELLO_HEADER_LEN sizeof(send_hello_hdr)
#define PDV_RREQ_HEADER_LEN  sizeof(PDV_rreq_hdr)
#define PDV_RREP_HEADER_LEN  sizeof(PDV_rrep_hdr)
#define PDV_RERR_HEADER_LEN  sizeof(PDV_rerr_hdr)
#define PDV_MSG_HEADER_LEN   sizeof(PDV_msg_hdr)

#define PDV_HELLO_RETRIES    3
#define PDV_RREQ_RETRIES     3
#define PDV_RREP_RETRIES     3
#define PDV_RERR_RETRIES     3
#define PDV_MSG_RETRIES      3
#define PDV_MAX_HOP          10

#define PDV_DEFAULT_PERIOD   100
#define PDV_RREQ_CACHE_TTL   5
#define PDV_ROUTE_TABLE_TTL  100

#define PDV_RREQ_CACHE_SIZE  10
#define PDV_ROUTE_TABLE_SIZE 10

#define INVALID_NODE_ID       0xFFFF
#define INVALID_INDEX         0xFF

#endif