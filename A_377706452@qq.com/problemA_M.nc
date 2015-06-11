#include "printf.h"
#include "Beacon.h"

//纯洪泛
module problemA_M {
  uses {
    interface Boot;
    interface SplitControl;
    interface Timer<TMilli> as OutTimer;    
    
    interface AMSend;
    interface Receive;
    interface PacketAcknowledgements;
    interface AMPacket;
    interface Random;
  }
}

implementation {
  
 message_t pkt;
 message_t* p_pkt;

 uint16_t src;
 uint16_t dest;
 uint16_t serialnumber;
 uint16_t oldserialnumber = 0;
 uint16_t newserialnumber = 0;

//cache只是记录已经发送过的帧，防止重复，形成环
 BeaconMsg cache_table[CACHE_SIZE];
 
 bool busy = FALSE;

 uint16_t i;
 uint16_t j;
 uint8_t k;
 uint8_t hop; 

  
  event void Boot.booted() {
   
    call SplitControl.start();

    for(i = 0; i < CACHE_SIZE; i++){
      cache_table[i].nodeidi = INVALIDATE_NODE_ID;
      cache_table[i].nodeidk = INVALIDATE_NODE_ID;
      cache_table[i].serialnumber = -1; 
    }

   //指向本地缓存中有效位置,发送一个广播帧之后，j自增，记录已经发送过的包
    j = 0;
    k = 0;

  }

  
  event void SplitControl.startDone(error_t err) {

    if (err == SUCCESS) {
      p_pkt = &pkt;
      call OutTimer.startPeriodicAt(9000,30);
    } else {
      call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err) {}

  bool isCached(am_addr_t src,am_addr_t dest){
    for(i=0;i<CACHE_SIZE;i++){
      if((cache_table[i].nodeidi == src ) && (cache_table[i].nodeidk == dest))
        return TRUE;
    }
    return FALSE;
  }
 
  void add_cache(am_addr_t src,am_addr_t dest, uint16_t serialnumber){
    cache_table[j].nodeidi = src;
    cache_table[j].nodeidk = dest;
    cache_table[j].serialnumber = serialnumber;
    j++; 
  }



event void OutTimer.fired(){
  if((newserialnumber - oldserialnumber) != 0){
    printf("GreenOrbs  %x\n",newserialnumber);
    printfflush();
    oldserialnumber = newserialnumber;
  }
}

  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
   
   if(len == sizeof(BeaconMsg)){
      BeaconMsg* bMsg = (BeaconMsg*) payload;
      NewBeaconMsg* nbMsg = (NewBeaconMsg*) (p_pkt->data);
      src = bMsg->nodeidi;
      dest = bMsg->nodeidk;
      serialnumber = bMsg->serialnumber;

      if(isCached(src,dest)){  //如果消息已经接收过，再次接收不做任何处理
          return bufPtr; 
      }else{
        add_cache(src,dest,serialnumber); 
      }

      if(TOS_NODE_ID == src){
        nbMsg->nodeidi = src;
        nbMsg->nodeidk = dest;
        nbMsg->serialnumber = serialnumber;
        nbMsg->hops = 5;

        if(!busy){
          call AMSend.send(TOS_BCAST_ADDR,p_pkt,sizeof(NewBeaconMsg));
          busy = TRUE;
        }

      }
  }else if(len == sizeof(NewBeaconMsg)){

    NewBeaconMsg* nbMsg = (NewBeaconMsg*) payload;
    NewBeaconMsg* send_bMsg = (NewBeaconMsg*) p_pkt->data;
    src = nbMsg->nodeidi;
    dest = nbMsg->nodeidk;
    serialnumber = nbMsg->serialnumber;
    hop = nbMsg->hops;

     if(isCached(src,dest)){  //如果消息已经接收过，再次接收不做任何处理
          return bufPtr; 
      }else{
        add_cache(src,dest,serialnumber); 
      }

    if(TOS_NODE_ID == dest){
      newserialnumber = nbMsg->serialnumber;
    }else{ //中间结点
      hop--;
      if(!busy&& hop>0){
        send_bMsg->nodeidi = src;
        send_bMsg->nodeidk = dest;
        send_bMsg->serialnumber = serialnumber;
        send_bMsg->hops = hop;
        call AMSend.send(TOS_BCAST_ADDR,p_pkt,sizeof(NewBeaconMsg));
        busy = TRUE;
      }  
    }
  }

    return bufPtr;
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    busy = FALSE;
  }

}

