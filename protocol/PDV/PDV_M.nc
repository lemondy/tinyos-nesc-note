
#include "PDV.h"

#define PDV_DEBUG  1

module PDV_M {
  provides {
    interface SplitControl;
    interface AMSend[am_id_t id];
    interface Receive[uint8_t id];
  }
  
  uses {
    interface SplitControl as AMControl;
    interface Timer<TMilli> as PDVTimer;
    interface Timer<TMilli> as RREQTimer;
    interface Leds;
    interface Random;
    interface AMPacket;
    interface Packet;

    interface AMSend as SendHELLO;
    interface AMSend as SendRREQ;
    interface AMSend as SendRREP;
    interface AMSend as SendRERR;

    interface Receive as ReceiveHELLO;
    interface Receive as ReceiveRREQ;
    interface Receive as ReceiveRREP;
    interface Receive as ReceiveRERR;


    interface AMSend as SubSend;
    interface Receive as SubReceive;
    interface PacketAcknowledgements;
  }
}

implementation {

  mssage_t hello_msg_;
  message_t rreq_msg_;
  message_t rrep_msg_;
  message_t rerr_msg_;
  message_t PDV_msg_;
  message_t app_msg_;
  
  message_t* p_hello_msg_;
  message_t* p_rreq_msg_;
  message_t* p_rrep_msg_;
  message_t* p_rerr_msg_;
  message_t* p_PDV_msg_;
  message_t* p_app_msg_;
  
  uint8_t hello_seq_ = 0;
  uint8_t rreq_seq_ = 0;
  
  bool hello_pending_   = FALSE;
  bool send_pending_    = FALSE;
  bool rreq_pending_    = FALSE;
  bool rrep_pending_    = FALSE;
  bool rerr_pending_    = FALSE;
  bool msg_pending_ = FALSE;
  
  uint8_t hello_retries_   = PDV_HELLO_RETRIES;
  uint8_t rreq_retries_    = PDV_RREQ_RETRIES;
  uint8_t rrep_retries_    = PDV_RREP_RETRIES;
  uint8_t rerr_retries_    = PDV_RERR_RETRIES;
  uint8_t msg_retries_     = PDV_MSG_RETRIES;
  
  PDV_ROUTE_TABLE route_table_[PDV_ROUTE_TABLE_SIZE];
  PDV_RREQ_CACHE rreq_cache_[PDV_RREQ_CACHE_SIZE];

  bool SendHELLO(am_addr_t dest, bool forward);
  task void resendHELLO();
  
  bool sendRREQ( am_addr_t dest, bool forward );
  task void resendRREQ();
  
  bool sendRREP( am_addr_t dest, bool forward );
  task void resendRREP();
  
  bool sendRERR( am_addr_t dest, am_addr_t src, bool forward );
  task void resendRERR();
  
  error_t forwardMSG( message_t* msg, am_addr_t nextHop, uint8_t len );
  void resendMSG();
  
  uint8_t get_rreq_cache_index( am_addr_t src, am_addr_t dest );
  bool is_rreq_cached( PDV_rreq_hdr* msg );
  bool add_rreq_cache( uint8_t seq, am_addr_t dest, am_addr_t src, uint8_t hop );
  void del_rreq_cache( uint8_t id );
  task void update_rreq_cache();
  
  uint8_t get_route_table_index( am_addr_t dest );
  bool add_route_table( uint8_t seq, am_addr_t dest, am_addr_t nexthop, uint8_t hop );
  void del_route_table( am_addr_t dest );
  am_addr_t get_next_hop( am_addr_t dest );
  
#if PDV_DEBUG
  void print_route_table();
  void print_rreq_cache();
#endif
  
  command error_t SplitControl.start() {
    int i;
    
    p_hello_msg_    = &hello_msg_;
    p_rreq_msg_     = &rreq_msg_;
    p_rrep_msg_     = &rrep_msg_;
    p_rerr_msg_     = &rerr_msg_;
    p_PDV_msg_     = &PDV_msg_;
    p_app_msg_      = &app_msg_;
    
    for(i = 0; i< PDV_ROUTE_TABLE_SIZE; i++) {
      route_table_[i].seq  = 0;
      route_table_[i].dest = INVALID_NODE_ID;
      route_table_[i].next = INVALID_NODE_ID;
      route_table_[i].hop  = 0;
    }
    
    for(i = 0; i< PDV_RREQ_CACHE_SIZE; i++) {
      rreq_cache_[i].seq  = 0;
      rreq_cache_[i].dest = INVALID_NODE_ID;
      rreq_cache_[i].src  = INVALID_NODE_ID;
      rreq_cache_[i].hop  = 0;
    }
    
    call AMControl.start();
    
    return SUCCESS;
  } // start
  
  
  command error_t SplitControl.stop() {
    call AMControl.stop();
    return SUCCESS;
  }
  
  
  event void AMControl.startDone( error_t e ) {
    if ( e == SUCCESS ) {

      call PDVTimer.startPeriodic( PDV_DEFAULT_PERIOD );
      signal SplitControl.startDone(e);
    } else {
      call AMControl.start();
    }
  }
  
  
  event void AMControl.stopDone(error_t e){
    call PDVTimer.stop();
    signal SplitControl.stopDone(e);
  }
  
   //--------------------------------------------------------------------------
  //  sendHELLO: This broadcasts the HELLO to find who is near to me.
  //-------------------------------------------------------------------------

  bool sendHELLO(am_addr_t dest, bool forward){
    send_Hello_hdr* hello_hdr = (send_Hello_hdr*) (p_hello_msg_ -> data);

    if( forward == FALSE) {  //when the node starts, it first communication with their neighborhood.
      hello_hdr->seq = hello_seq_++;
      hello_hdr->hello = HELLO;
      hello_hdr->src = TOS_NODE_ID;  //My own id.

      if(call SendHELLO.send(TOS_BCAST_ADDR, p_hello_msg_, PDV_HELLO_HEADER_LEN) == SUCCESS){
          return true;
      }
    }
  }

  //--------------------------------------------------------------------------
  //  sendRREQ: This broadcasts the RREQ to find the path from the source to
  //  the destination.
  //-------------------------------------------------------------------------
  bool sendRREQ( am_addr_t dest, bool forward ) {
    PDV_rreq_hdr* PDV_hdr = (PDV_rreq_hdr*)(p_rreq_msg_->data);
    
    //dbg("PDV", "%s\t PDV: sendRREQ() dest: %d\n", sim_time_string(), dest);
    
    if( rreq_pending_ == TRUE ) {
      return FALSE;
    }
    
    if( forward == FALSE ) { // generate the RREQ for the first time
      PDV_hdr->seq      = rreq_seq_++; 
      PDV_hdr->dest     = dest;
      PDV_hdr->src      = call AMPacket.address();
      PDV_hdr->hop      = 1;
      add_rreq_cache( PDV_hdr->seq, PDV_hdr->dest, PDV_hdr->src, 0 );
    } else { // forward the RREQ
      PDV_hdr->hop++;
    }
    
    if (!send_pending_) {
      if( call SendRREQ.send(TOS_BCAST_ADDR, p_rreq_msg_, 
                                    PDV_RREQ_HEADER_LEN) == SUCCESS) {
        dbg("PDV", "%s\t PDV: sendRREQ()\n", sim_time_string());
        send_pending_ = TRUE;
        return TRUE;
      }
    }
    
    rreq_pending_ = TRUE;
    rreq_retries_ = PDV_RREQ_RETRIES;
    return FALSE;
  }
  
  
  //--------------------------------------------------------------------------
  //  sendRREP: This forwards the RREP to the nexthop of the source of RREQ
  //  to establish and inform the route.
  //--------------------------------------------------------------------------
  bool sendRREP( am_addr_t dest, bool forward ){
    
    dbg("PDV_DBG", "%s\t PDV: sendRREP() dest: %d send_pending_: %d\n", 
                                      sim_time_string(), dest, send_pending_);
    
    if ( !send_pending_ ) {
      call PacketAcknowledgements.requestAck(p_rrep_msg_);
      if( call SendRREP.send(dest, p_rrep_msg_, 
                                           PDV_RREP_HEADER_LEN) == SUCCESS) {
        dbg("PDV", "%s\t PDV: sendRREP() to %d\n", sim_time_string(), dest);
        send_pending_ = TRUE;
        return TRUE;
      }
    }
    
    rrep_pending_ = TRUE;
    rrep_retries_ = PDV_RREP_RETRIES;
    return FALSE;
  }
  
  
  //--------------------------------------------------------------------------
  //  sendRERR: If the node fails to transmit a message over the retransmission
  //  limit, it will send RERR to the source node of the message.
  //--------------------------------------------------------------------------
  bool sendRERR( am_addr_t dest, am_addr_t src, bool forward ){
    PDV_rerr_hdr* PDV_hdr = (PDV_rerr_hdr*)(p_rerr_msg_->data);
    am_addr_t target;
    
    dbg("PDV_DBG", "%s\t PDV: sendRERR() dest: %d\n", sim_time_string(), dest);
    
    PDV_hdr->dest = dest;
    PDV_hdr->src = src;
    
    target = get_next_hop( src );
    
    if (!send_pending_) {
      if( call SendRERR.send(target, p_rerr_msg_, PDV_RERR_HEADER_LEN)) {
        dbg("PDV", "%s\t PDV: sendRREQ() to %d\n", sim_time_string(), target);
        send_pending_ = TRUE;
        return TRUE;
      }
    }
    
    rerr_pending_ = TRUE;
    rerr_retries_ = PDV_RERR_RETRIES;
    return FALSE;
  }
  
  task void resendHELLO() {

    if(hello_retries_ <= 0){
      hello_pending_ = FALSE;
      return;
    }
    hello_retries_ --;

    if( !send_pending_ ){
      if( call SendHELLO.send(TOS_BCAST_ADDR, p_hello_msg_, PDV_HELLO_HEADER_LEN)){
        send_pending_ = TRUE;
        hello_pending_ = TRUE;
      }
    }
  }
  
  task void resendRREQ() {
    dbg("PDV", "%s\t PDV: resendRREQ()\n", sim_time_string());
    
    if(rreq_retries_ <= 0){
      rreq_pending_ = FALSE;
      return;
    }
    rreq_retries_--;
    
    if ( !send_pending_ ) {
      if( call SendRREQ.send(TOS_BCAST_ADDR, p_rreq_msg_, PDV_RREQ_HEADER_LEN) ) {
        send_pending_ = TRUE;
        rreq_pending_ = FALSE;
      }
    }
  }
  
  
  task void resendRREP(){
    am_addr_t dest = call AMPacket.destination( p_rrep_msg_ );
    if( rrep_retries_ == 0 ) {
      rrep_pending_ = FALSE;
      return;
    }
    rrep_retries_--;
    
    if ( !send_pending_ ) {
      call PacketAcknowledgements.requestAck( p_rrep_msg_ );
      if( call SendRREP.send( dest, 
                               p_rrep_msg_, PDV_RREP_HEADER_LEN) == SUCCESS) {
        dbg("PDV", "%s\t PDV: resendRREP() to %d\n", sim_time_string(), dest);
        send_pending_ = TRUE;
        rrep_pending_ = FALSE;
      }
    }
  }
  
  
  task void resendRERR(){
    am_addr_t dest = call AMPacket.destination( p_rerr_msg_ );
    if( rerr_retries_ == 0 ) {
      rerr_pending_ = FALSE;
      return;
    }
    rerr_retries_--;
    
    if ( !send_pending_ ) {
      call PacketAcknowledgements.requestAck( p_rerr_msg_ );
      if( call SendRERR.send( dest, 
                               p_rerr_msg_, PDV_RERR_HEADER_LEN) == SUCCESS) {
        dbg("PDV", "%s\t PDV: resendRERR() to %d\n", sim_time_string());
        send_pending_ = TRUE;
        rerr_pending_ = FALSE;
      }
    }
  }
  
  
  //--------------------------------------------------------------------------
  //  resendMSG: This is triggered by the timer. If the forward_retries_ equals
  //  zero, the retransmission will be canceled. Or, the cached message will
  //  be retransmitted.
  //--------------------------------------------------------------------------
  void resendMSG() {
    if( msg_retries_ == 0 ) {
      msg_pending_ = FALSE;
      return;
    }
    msg_retries_--;
    call PacketAcknowledgements.requestAck( p_PDV_msg_ );
    if( !send_pending_ ) {
      if( call SubSend.send( call AMPacket.destination(p_PDV_msg_),
                        p_PDV_msg_,
                        call Packet.payloadLength(p_PDV_msg_) ) == SUCCESS ) {
        dbg("PDV", "%s\t PDV: resendMSG() broadcast\n", sim_time_string());
        send_pending_ = TRUE;
        msg_pending_ = FALSE;
      }
    }
  }
  
  
  uint8_t get_rreq_cache_index( am_addr_t src, am_addr_t dest ){
    int i;
    for( i=0 ; i < PDV_RREQ_CACHE_SIZE ; i++ ) {
      if( rreq_cache_[i].src == src && rreq_cache_[i].dest == dest ) {
        return i;
      }
      return INVALID_INDEX;
    }
  }
  
  
  bool is_rreq_cached( PDV_rreq_hdr* rreq_hdr ) {
    int i;
    
    for( i=0; i < PDV_RREQ_CACHE_SIZE ; i++ ) {
      if( rreq_cache_[i].dest == INVALID_NODE_ID ) {
        return TRUE;
      }
      if( rreq_cache_[i].src == rreq_hdr->src && rreq_cache_[i].dest == rreq_hdr->dest ) {
        if( rreq_cache_[i].seq < rreq_hdr->seq || 
           ( rreq_cache_[i].seq == rreq_hdr->seq && rreq_cache_[i].hop > rreq_hdr->hop )) {
          // this is a newer rreq
	  return TRUE;
        } else {
          return FALSE;
        }
      }
    }
    return TRUE;
  } //
  
  
  bool add_rreq_cache( uint8_t seq, am_addr_t dest, am_addr_t src, uint8_t hop ) {
    uint8_t i;
    uint8_t id = PDV_RREQ_CACHE_SIZE;
    
    for( i=0; i < PDV_RREQ_CACHE_SIZE-1 ; i++ ) {
      if( rreq_cache_[i].src == src && rreq_cache_[i].dest == dest ) {
        id = i;
        break;
      }
      if( rreq_cache_[i].dest == INVALID_NODE_ID )
      break;
    }
    
    if( id != PDV_RREQ_CACHE_SIZE ) {
      if( rreq_cache_[i].src == src && rreq_cache_[i].dest == dest ) {
        if( rreq_cache_[id].seq < seq || rreq_cache_[id].hop > hop ) {
          rreq_cache_[id].seq = seq;
          rreq_cache_[id].hop = hop;
          rreq_cache_[i].ttl  = PDV_RREQ_CACHE_TTL;
          return TRUE;
        }
      }
    } else if( i != PDV_RREQ_CACHE_SIZE ) {
      rreq_cache_[i].seq  = seq;
      rreq_cache_[i].dest = dest;
      rreq_cache_[i].src  = src;
      rreq_cache_[i].hop  = hop;
      rreq_cache_[i].ttl  = PDV_RREQ_CACHE_TTL;
      return TRUE;
    }
    
    print_rreq_cache();
    return FALSE;
  }
  
  
  void del_rreq_cache( uint8_t id ) {
    uint8_t i;
    
    for(i = id; i< PDV_ROUTE_TABLE_SIZE-1; i++) {
      if(rreq_cache_[i+1].dest == INVALID_NODE_ID) {
        break;
      }
      rreq_cache_[i] = rreq_cache_[i+1];
    }
    
    rreq_cache_[i].dest = INVALID_NODE_ID;
    rreq_cache_[i].src = INVALID_NODE_ID;
    rreq_cache_[i].seq  = 0;
    rreq_cache_[i].hop  = 0;
    
    print_rreq_cache();
  }
  
  
  //--------------------------------------------------------------------------
  //  update_rreq_cache: This is triggered periodically by the timer.
  //  If the ttl of a rreq_cache entity equals to zero, the entity will be 
  //  removed.
  //--------------------------------------------------------------------------
  task void update_rreq_cache() {
    uint8_t i;
    for( i=0 ; i < PDV_RREQ_CACHE_SIZE-1 ; i++ ) {
      if( rreq_cache_[i].dest == INVALID_NODE_ID )
	break;
      else if( rreq_cache_[i].ttl-- == 0 )
        del_rreq_cache(i);
    }
  }
  
  
  //--------------------------------------------------------------------------
  //  get_route_table_index: Return the index which is correspoing to
  //  the destination
  //--------------------------------------------------------------------------
  uint8_t get_route_table_index( am_addr_t dest ) {
    int i;
    for(i=0; i< PDV_ROUTE_TABLE_SIZE; i++) {
      if(route_table_[i].dest == dest)
        return i;
    }
    return INVALID_INDEX;
  } //
  
  
  void del_route_table( am_addr_t dest ) {
    uint8_t i;
    uint8_t id = get_route_table_index( dest );
    
    dbg("PDV", "%s\t PDV: del_route_table() dest:%d\n",
                                       sim_time_string(), dest);
    
    for(i = id; i< PDV_ROUTE_TABLE_SIZE-1; i++) {
      if(route_table_[i+1].dest == INVALID_NODE_ID) {
        break;
      }
      route_table_[i] = route_table_[i+1];
    }
    
    route_table_[i].dest = INVALID_NODE_ID;
    route_table_[i].next = INVALID_NODE_ID;
    route_table_[i].seq  = 0;
    route_table_[i].hop  = 0;
    
    print_route_table();
  }
  
  
  //--------------------------------------------------------------------------
  //  add_route_table: If a route information is a new or fresh one, it is 
  //  added to the route table.
  //--------------------------------------------------------------------------
  bool add_route_table( uint8_t seq, am_addr_t dest, am_addr_t nexthop, uint8_t hop ) {
    uint8_t i;
    uint8_t id = PDV_ROUTE_TABLE_SIZE;
    
    dbg("PDV_DBG", "%s\t PDV: add_route_table() seq:%d dest:%d next:%d hop:%d\n",
                                    sim_time_string(), seq, dest, nexthop, hop);
    for( i=0 ; i < PDV_ROUTE_TABLE_SIZE-1 ; i++ ) {
      if( route_table_[i].dest == dest ) {
        id = i;
        break;
      }
      if( route_table_[i].dest == INVALID_NODE_ID ) {
        break;
      }
    }
    
    if( id != PDV_ROUTE_TABLE_SIZE ) {
      if( route_table_[id].next == nexthop ) {
        if( route_table_[id].seq < seq || route_table_[id].hop > hop ) {
          route_table_[id].seq = seq;
          route_table_[id].hop = hop;
          //route_table_[id].ttl = 0;
          return TRUE;
        }
      }
    } else if( i != PDV_ROUTE_TABLE_SIZE ) {
      route_table_[i].seq  = seq;
      route_table_[i].dest = dest;
      route_table_[i].next = nexthop;
      route_table_[i].hop  = hop;
      //route_table_[i].ttl = 0;
      return TRUE;
    }
    return FALSE;
    print_route_table();
  }
  
  
  //--------------------------------------------------------------------------
  //  get_next_hop: Return the nexthop node address of the message if the 
  //  address exists in the route table.
  //--------------------------------------------------------------------------
  am_addr_t get_next_hop( am_addr_t dest ) {
    int i;
    for( i=0 ; i < PDV_ROUTE_TABLE_SIZE ; i++ ) {
      if(route_table_[i].dest == dest) {
        return route_table_[i].next;
      }
    }
    return INVALID_NODE_ID;
  }
  
  
  //--------------------------------------------------------------------------
  //  forwardMSG: The node forwards a message to the next-hop node if the 
  //  target of the message is not itself.
  //--------------------------------------------------------------------------
  error_t forwardMSG( message_t* p_msg, am_addr_t nexthop, uint8_t len ) {
    PDV_msg_hdr* PDV_hdr = (PDV_msg_hdr*)(p_msg->data);
    PDV_msg_hdr* msg_PDV_hdr = (PDV_msg_hdr*)(p_PDV_msg_->data);
    uint8_t i;
    
    if ( msg_pending_ ) {
      dbg("PDV", "%s\t PDV: forwardMSG() msg_pending_\n", sim_time_string());
      return FAIL;
    }
    dbg("PDV_DBG", "%s\t PDV: forwardMSG() try to forward to %d \n", 
                                                    sim_time_string(), nexthop);
    
    // forward MSG
    msg_PDV_hdr->dest = PDV_hdr->dest;
    msg_PDV_hdr->src  = PDV_hdr->src;
    msg_PDV_hdr->app  = PDV_hdr->app;
    
    for( i=0 ; i < len-PDV_MSG_HEADER_LEN ; i++ ) {
      msg_PDV_hdr->data[i] = PDV_hdr->data[i];
    }
    
    call PacketAcknowledgements.requestAck(p_PDV_msg_);
    
    if( call SubSend.send(nexthop, p_PDV_msg_, len) == SUCCESS ) {
      dbg("PDV", "%s\t PDV: forwardMSG() send MSG to: %d\n", 
                                                 sim_time_string(), nexthop);
      msg_retries_ = PDV_MSG_RETRIES;
      msg_pending_ = TRUE;
    } else {
      dbg("PDV", "%s\t PDV: forwardMSG() fail to send\n", sim_time_string());
      msg_pending_ = FALSE;
    }
    return SUCCESS;
  }
  
  
  //--------------------------------------------------------------------------
  //  AMSend.send: If there is a route to the destination, the message will be 
  //  sent to the next-hop node for the destination. Or, the node will broadcast
  //  the RREQ.
  //--------------------------------------------------------------------------
  command error_t AMSend.send[am_id_t id](am_addr_t addr, message_t* msg, uint8_t len) {
    uint8_t i;
    PDV_msg_hdr* PDV_hdr = (PDV_msg_hdr*)(p_PDV_msg_->data);
    am_addr_t nexthop = get_next_hop( addr );
    am_addr_t me = call AMPacket.address();
    
    dbg("PDV", "%s\t PDV: AMSend.send() dest: %d id: %d len: %d nexthop: %d\n", 
                sim_time_string(), addr, id, len, nexthop);
    
    if( addr == me ) {
      return SUCCESS;
    }
    /* If the next-hop node for the destination does not exist, the RREQ will be
       broadcasted */
    if( nexthop == INVALID_NODE_ID ) {
      if( !rreq_pending_ ) {
        dbg("PDV", "%s\t PDV: AMSend.send() a new destination\n", 
                                                             sim_time_string());
        sendRREQ( addr, FALSE );
        return SUCCESS;
      }
      return FAIL;
    }
    dbg("PDV", "%s\t PDV: AMSend.send() there is a route to %d\n", 
                                                        sim_time_string(), addr);
    PDV_hdr->dest = addr;
    PDV_hdr->src  = me;
    PDV_hdr->app  = id;
    
    for( i=0;i<len;i++ ) {
      PDV_hdr->data[i] = msg->data[i];
    }
    
    call PacketAcknowledgements.requestAck(p_PDV_msg_);
    
    if( !send_pending_ ) {
      if( call SubSend.send( nexthop, p_PDV_msg_, len + PDV_MSG_HEADER_LEN ) == SUCCESS ) {
        send_pending_ = TRUE;
        return SUCCESS;
      }
      msg_pending_ = TRUE;
    }
    return FAIL;
  }
  
  
  //--------------------------------------------------------------------------
  //  SendRREQ.sendDone: If the RREQ transmission is finished, it will release
  //  the RREQ and SEND pendings.
  //--------------------------------------------------------------------------
  event void SendRREQ.sendDone(message_t* p_msg, error_t e) {
    dbg("PDV_DBG", "%s\t PDV: SendRREQ.sendDone()\n", sim_time_string());
    send_pending_ = FALSE;
    rreq_pending_ = FALSE;
  }
  
  
  //--------------------------------------------------------------------------
  //  SendRREP.sendDone: If the RREP transmission is finished, it will release
  //  the RREP and SEND pendings.
  //--------------------------------------------------------------------------
  event void SendRREP.sendDone(message_t* p_msg, error_t e) {
    dbg("PDV_DBG", "%s\t PDV: SendRREP.sendDone()\n", sim_time_string());
    send_pending_ = FALSE;
    if( call PacketAcknowledgements.wasAcked(p_msg) )
      rrep_pending_ = FALSE;
    else
      rrep_pending_ = TRUE;
  }
  
  
  //--------------------------------------------------------------------------
  //  SendRERR.sendDone: If the RERR transmission is finished, it will release
  //  the RERR and SEND pendings.
  //--------------------------------------------------------------------------
  event void SendRERR.sendDone(message_t* p_msg, error_t e) {
    dbg("PDV_DBG", "%s\t PDV: SendRERR.sendDone() \n", sim_time_string());
    send_pending_ = FALSE;
    if( call PacketAcknowledgements.wasAcked(p_msg) )
      rerr_pending_ = FALSE;
    else
      rerr_pending_ = TRUE;
  }
  

  /--------------------------------------------------------------------------
  //  ReceiveHELLO.receive: If the neighborhood of the source receives hello frame, the node will
  //  send the hello back to establish one path between in the route table. 
  //--------------------------------------------------------------------------


  event message_t* ReceiveHELLO.receive(message_t* p_msg, void* payload, uint8_t len){

    send_hello_hdr* hello_hdr = (send_hello_hdr*) (p_msg->data);
    uint8_t seq = hello_hdr -> seq;
    am_addr_t src = hello_hdr -> src;
    am_addr_t hello = hello_hdr -> hello;

    if(hello == HELLO){
      add_route_table(seq, src, src, 1);
      call SendHELLO.send(src,p_msg, len);
    }

    return p_msg;
  }
  
  //--------------------------------------------------------------------------
  //  ReceiveRREQ.receive: If the destination of the RREQ is me, the node will
  //  send the RREP back to establish the reverse route. Or, the node forwards
  //  the RREQ to the nextt-hop node.
  //--------------------------------------------------------------------------
  event message_t* ReceiveRREQ.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    bool cached = FALSE;
    bool added  = FALSE;
    
    am_addr_t me  = call AMPacket.address();
    am_addr_t src = call AMPacket.source( p_msg );
    PDV_rreq_hdr* PDV_hdr      = (PDV_rreq_hdr*)(p_msg->data);
    PDV_rreq_hdr* rreq_PDV_hdr = (PDV_rreq_hdr*)(p_rreq_msg_->data);
    PDV_rrep_hdr* rrep_PDV_hdr = (PDV_rrep_hdr*)(p_rrep_msg_->data);
    
    dbg("PDV", "%s\t PDV: ReceiveRREQ.receive() src:%d dest: %d \n",
                     sim_time_string(), PDV_hdr->src, PDV_hdr->dest);
    
    if( PDV_hdr->hop > PDV_MAX_HOP ) {
      return p_msg;
    }
    
    /* if the received RREQ is already received one, it will be ignored */
    if( !is_rreq_cached( PDV_hdr ) ) {
      dbg("PDV_DBG", "%s\t PDV: ReceiveRREQ.receive() already received one\n", 
                                                             sim_time_string());
      return p_msg;
    }
    
    /* add the route information into the route table */
    add_route_table( PDV_hdr->seq, src, src, 1 );
    added = add_route_table( PDV_hdr->seq, PDV_hdr->src, src, PDV_hdr->hop );
    
    cached = add_rreq_cache( PDV_hdr->seq, PDV_hdr->dest, PDV_hdr->src, PDV_hdr->hop );
    
    
    /* if the destination of the RREQ is me, the node will send the RREP */
    if( PDV_hdr->dest == me && added ) {
      rrep_PDV_hdr->seq  = PDV_hdr->seq;
      rrep_PDV_hdr->dest = PDV_hdr->dest;
      rrep_PDV_hdr->src  = PDV_hdr->src;
      rrep_PDV_hdr->hop  = 1;
      sendRREP( src, FALSE );
      return p_msg;
    }
    
    // not for me
    if( !rreq_pending_ && PDV_hdr->src != me && cached ) {
      // forward RREQ
      rreq_PDV_hdr->seq  = PDV_hdr->seq;
      rreq_PDV_hdr->dest = PDV_hdr->dest;
      rreq_PDV_hdr->src  = PDV_hdr->src;
      rreq_PDV_hdr->hop  = PDV_hdr->hop + 1;
      call RREQTimer.stop();
      call RREQTimer.startOneShot( (call Random.rand16() % 7) * 10 );
    }
    
    return p_msg;
  }
  
  
  //--------------------------------------------------------------------------
  //  ReceiveRREP.receive: If the source address of the RREP is me, it means
  //  the route to the destination is established. Or, the node forwards
  //  the RREP to the next-hop node.
  //--------------------------------------------------------------------------
  event message_t* ReceiveRREP.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    PDV_rrep_hdr* PDV_hdr = (PDV_rrep_hdr*)(p_msg->data);
    PDV_rrep_hdr* rrep_PDV_hdr = (PDV_rrep_hdr*)(p_rrep_msg_->data);
    am_addr_t src = call AMPacket.source(p_msg);
    
    dbg("PDV", "%s\t PDV: ReceiveRREP.receive() src: %d dest: %d \n", 
                             sim_time_string(), PDV_hdr->src, PDV_hdr->dest);
    if( PDV_hdr->src == call AMPacket.address() ) {
      add_route_table( PDV_hdr->seq, PDV_hdr->dest, src, PDV_hdr->hop );
    } else { // not to me
      am_addr_t dest = get_next_hop( PDV_hdr->src );
      if( dest != INVALID_NODE_ID ) {
        // forward RREP
        rrep_PDV_hdr->seq  = PDV_hdr->seq;
        rrep_PDV_hdr->dest = PDV_hdr->dest;
        rrep_PDV_hdr->src  = PDV_hdr->src;
        rrep_PDV_hdr->hop  = PDV_hdr->hop++;
        
        add_route_table( PDV_hdr->seq, PDV_hdr->dest, src, PDV_hdr->hop );
        sendRREP( dest, TRUE );
      }
    }
    return p_msg;
  }
  
  
  event message_t* ReceiveRERR.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    PDV_rerr_hdr* PDV_hdr = (PDV_rerr_hdr*)(p_msg->data);
    dbg("PDV", "%s\t PDV: ReceiveRERR.receive()\n", sim_time_string());
    del_route_table( PDV_hdr->dest );
    if( PDV_hdr->src != call AMPacket.address())
      sendRERR( PDV_hdr->dest, PDV_hdr->src, TRUE );
    
    return p_msg;
  }
  
  
  command error_t AMSend.cancel[am_id_t id](message_t* msg) {
    return call SubSend.cancel(msg);
  }
  
  
  command uint8_t AMSend.maxPayloadLength[am_id_t id]() {
    return call Packet.maxPayloadLength();
  }
  
  
  command void* AMSend.getPayload[am_id_t id](message_t* m, uint8_t len) {
    return call Packet.getPayload(m, 0);
  }
  
  /*
  command void * Receive.getPayload[uint8_t am](message_t *msg, uint8_t *len){
    return call Packet.getPayload(msg, len);
  }
  
  
  command uint8_t Receive.payloadLength[uint8_t am](message_t *msg){
    return call Packet.payloadLength(msg);
  }
  */
  
  /***************** SubSend Events ****************/
  event void SubSend.sendDone(message_t* p_msg, error_t e) {
    PDV_msg_hdr* PDV_hdr = (PDV_msg_hdr*)(p_msg->data);
    bool wasAcked = call PacketAcknowledgements.wasAcked(p_msg);
    am_addr_t dest = call AMPacket.destination(p_PDV_msg_);
    
    dbg("PDV_DBG", "%s\t PDV: SubSend.sendDone() dest:%d src:%d wasAcked:%d\n",
                   sim_time_string(), PDV_hdr->dest, PDV_hdr->src, wasAcked);
    
    send_pending_ = FALSE;
    
    if ( msg_pending_ == TRUE && p_msg == p_PDV_msg_ ) {
      if ( wasAcked ) {
        msg_retries_ = 0;
        msg_pending_ = FALSE;
      } else {
        msg_retries_--;
        if( msg_retries_ > 0 ) {
          dbg("PDV", "%s\t PDV: SubSend.sendDone() msg was not acked, resend\n",
                                                             sim_time_string());
          call PacketAcknowledgements.requestAck( p_PDV_msg_ );
          call SubSend.send( dest, p_PDV_msg_, 
                                     call Packet.payloadLength(p_PDV_msg_) );
        } else {
          dbg("PDV", "%s\t PDV: SubSend.sendDone() route may be corrupted\n", 
                                                             sim_time_string());
          msg_pending_ = FALSE;
          del_route_table( dest );
          sendRERR( PDV_hdr->dest, PDV_hdr->src, FALSE );
        }
      }
    } else {
      signal AMSend.sendDone[PDV_hdr->app](p_msg, e);
    }
  }
  
  
  /***************** SubReceive Events ****************/
  event message_t* SubReceive.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    uint8_t i;
    PDV_msg_hdr* PDV_hdr = (PDV_msg_hdr*)(p_msg->data);
    
    dbg("PDV", "%s\t PDV: SubReceive.receive() dest: %d src:%d\n",
                    sim_time_string(), PDV_hdr->dest, PDV_hdr->src);
    
    if( PDV_hdr->dest == call AMPacket.address() ) {
      dbg("PDV", "%s\t PDV: SubReceive.receive() deliver to upper layer\n", 
                                                             sim_time_string());
      for( i=0;i<len;i++ ) {
        p_app_msg_->data[i] = PDV_hdr->data[i];
      }
      p_msg = signal Receive.receive[PDV_hdr->app]( p_app_msg_, p_app_msg_->data, 
                                                     len - PDV_MSG_HEADER_LEN );
    } else {
      am_addr_t nexthop = get_next_hop( PDV_hdr->dest );
      dbg("PDV", "%s\t PDV: SubReceive.receive() deliver to next hop:%x\n",
                                                  sim_time_string(), nexthop);
      /* If there is a next-hop for the destination of the message, 
         the message will be forwarded to the next-hop.            */
      if (nexthop != INVALID_NODE_ID) {
        forwardMSG( p_msg, nexthop, len );
      }
    }
    return p_msg;
  }
  
  
  event void PDVTimer.fired() {
    dbg("PDV_DBG2", "%s\t PDV: Timer.fired()\n", sim_time_string());
    if( rreq_pending_ ){
      post resendRREQ();
    }
    
    if( rrep_pending_ ) {
      post resendRREP();
    }
    
    if( rreq_pending_ ) {
      post resendRERR();
    }
    
    post update_rreq_cache();
  }
  
  
  event void RREQTimer.fired() {
    dbg("PDV_DBG", "%s\t PDV: RREQTimer.fired()\n", sim_time_string());
    sendRREQ( 0 , TRUE );
  }
  
  /***************** Defaults ****************/
  default event void AMSend.sendDone[uint8_t id](message_t* msg, error_t err) {
    return;
  }
  
  default event message_t* Receive.receive[am_id_t id](message_t* msg, void* payload, uint8_t len) {
    return msg;
  }
  
  
#if PDV_DEBUG  
  void print_route_table(){
    uint8_t i;
    for( i=0; i < PDV_ROUTE_TABLE_SIZE ; i++ ) {
      if(route_table_[i].dest == INVALID_NODE_ID)
        break;
      dbg("PDV_DBG2", "%s\t PDV: ROUTE_TABLE i: %d: dest: %d next: %d seq:%d hop: %d \n", 
           sim_time_string(), i, route_table_[i].dest, route_table_[i].next, 
                 route_table_[i].seq, route_table_[i].hop );
    }
  }
  
  
  void print_rreq_cache() {
    uint8_t i;
    for( i=0 ; i < PDV_RREQ_CACHE_SIZE ; i++ ) {
      if(rreq_cache_[i].dest == INVALID_NODE_ID )
        break;
      dbg("PDV_DBG2", "%s\t PDV: RREQ_CACHE i: %d: dest: %d src: %d seq:%d hop: %d \n", 
           sim_time_string(), i, rreq_cache_[i].dest, rreq_cache_[i].src, rreq_cache_[i].seq, rreq_cache_[i].hop );
    }
  }
#endif

}

