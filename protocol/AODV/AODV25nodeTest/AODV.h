/*
 * Copyright (c) 2008 Junseok Kim
 * Author: Junseok Kim <jskim@usn.konkuk.ac.kr> <http://usn.konkuk.ac.kr/~jskim>
 * Date: 2008/05/30
 * Version: 0.0.1
 * Published under the terms of the GNU General Public License (GPLv2).
 */
 #ifndef AODV_H
 #define AODV_H

 #define AM_AODV_HELLO         9
#define AM_AODV_RREQ          10
#define AM_AODV_RREP          11
#define AM_AODV_RERR          12
#define AM_AODV_MSG           13

enum{
  HELLO = 0xffff
};

typedef nx_struct{
  nx_uint8_t seq;
  nx_uint16_t hello;
  nx_uint8_t src;
} send_hello;

typedef nx_struct{
  nx_uint8_t seq;
  nx_uint8_t me;
} receive_hello;

typedef nx_struct {
  nx_uint8_t    seq;
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    hop;
} aodv_rreq_hdr;


typedef nx_struct {
  nx_uint8_t    seq;
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    hop;
} aodv_rrep_hdr;


typedef nx_struct {
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
} aodv_rerr_hdr;


typedef nx_struct {
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    app;
  nx_uint8_t    data[1];
} aodv_msg_hdr;


typedef struct {
  uint8_t    seq;
  am_addr_t  dest;
  am_addr_t  next;
  uint8_t    hop;
  uint8_t    ttl;
} AODV_ROUTE_TABLE;


typedef struct {
  uint8_t    seq;
  am_addr_t  dest;
  am_addr_t  src;
  uint8_t    hop;
  uint8_t    ttl;
} AODV_RREQ_CACHE;


#define AODV_RREQ_HEADER_LEN  sizeof(aodv_rreq_hdr)
#define AODV_RREP_HEADER_LEN  sizeof(aodv_rrep_hdr)
#define AODV_RERR_HEADER_LEN  sizeof(aodv_rerr_hdr)
#define AODV_MSG_HEADER_LEN   sizeof(aodv_msg_hdr)

#define AODV_RREQ_RETRIES     3
#define AODV_RREP_RETRIES     3
#define AODV_RERR_RETRIES     3
#define AODV_MSG_RETRIES      3
#define AODV_MAX_HOP          10

#define AODV_DEFAULT_PERIOD   100
#define AODV_RREQ_CACHE_TTL   5
#define AODV_ROUTE_TABLE_TTL  100

#define AODV_RREQ_CACHE_SIZE  10
#define AODV_ROUTE_TABLE_SIZE 10

#define INVALID_NODE_ID       0xFFFF
#define INVALID_INDEX         0xFF

#endif