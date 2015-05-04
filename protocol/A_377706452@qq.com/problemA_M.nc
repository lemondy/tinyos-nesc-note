
#include "printf.h"
#include "Beacon.h"

module problemA_M {
  uses {
    interface Boot;
    interface SplitControl;
    interface Timer<TMilli> as OutTimer;    
    interface AMSend;
    interface Receive;
    interface AMSend as SendHello;
    interface Receive as ReceiveHello;
    interface Leds;
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
 uint16_t threshold = (0xffff / 2);
 uint16_t probability = 0;

 BeaconMsg cache_table[CACHE_SIZE];
 neighboor_node_table neighboor_table[NEIGHBOOR_SIZE];
 stop_bcast* stopb;

 bool isStopBcast = FALSE;

 uint16_t i;
 uint16_t j;
 uint16_t k;

 void sendHello(am_addr_t dest);
  
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

    for(i=0; i < NEIGHBOOR_SIZE; i++){
      neighboor_table[i].neighboor = INVALIDATE_NODE_ID;
    }


    //初始时每个节点广播一个hello帧
    sendHello(TOS_BCAST_ADDR);
  }
  
   void setLeds(uint16_t val) {
    if (val & 0x01)
      call Leds.led0On();
    else 
      call Leds.led0Off();
    if (val & 0x02)
      call Leds.led1On();
    else
      call Leds.led1Off();
    if (val & 0x04)
      call Leds.led2On();
    else
      call Leds.led2Off();
  }

  void sendHello(am_addr_t dest){
    send_hello* sendhello = (send_hello*) (p_pkt->data);
    sendhello->hello = HELLO;

    call SendHello.send(dest,p_pkt,sizeof(send_hello));
  }
  
  event void SplitControl.startDone(error_t err) {
    if (err == SUCCESS) {
      p_pkt = &pkt;
      call OutTimer.startPeriodic(50);    
    } else {
      call SplitControl.start();
    }

  }
  
  bool isCached(am_addr_t src,am_addr_t dest){
    for(i=0;i<CACHE_SIZE;i++){
      if((cache_table[i].nodeidi == src ) && (cache_table[i].nodeidk == dest))
        return TRUE;
    }
    return FALSE;
  }
 
 bool add_cache(am_addr_t src,am_addr_t dest, uint16_t serialnumber){
  cache_table[j].nodeidi = src;
  cache_table[j].nodeidk = dest;
  cache_table[j].serialnumber = serialnumber;
  j++; 
 }

 bool add_neighboor(am_addr_t id){
  neighboor_table[k] = id;
  k++;
 }

 bool isNeighboor(am_addr_t id){
  for(i=0;i<NEIGHBOOR_SIZE;i++){
    if(neighboor_table[i].neighboor == id){
      return TRUE;
    }
  }
  return FALSE;
 }
  event void SplitControl.stopDone(error_t err) {
    // do nothing
  }
  
  event void OutTimer.fired(){
    if((newserialnumber - oldserialnumber) != 0){
      printf("GreenOrbs  %x\n",newserialnumber);
      printfflush();
     // setLeds(newserialnumber);
      oldserialnumber = newserialnumber;
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){

  }

  event void SendHello.sendDone(message_t* msg, error_t err){
    
  }
  event message_t* ReceiveHello.receive(message_t* msg, void* payload, uint8_t len){
    if(len == sizeof(send_hello)){
      send_hello* receiveHello_msg = (send_hello*) payload;
      am_addr_t me = call AMPacket.address();
      am_addr_t src = call AMPacket.source(msg);

      if(receiveHello_msg->hello == HELLO){
          add_neighboor(src);
          sendHello(src);
      } 
    }
  }
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
   
   if(len == sizeof(BeaconMsg)){
      BeaconMsg* bMsg = (BeaconMsg*) payload;
      am_addr_t me = call AMPacket.address();
      src = bMsg->nodeidi;
      dest = bMsg->nodeidk;
      serialnumber = bMsg->serialnumber;

      if(isCached(src,dest)){
          return bufPtr; 
      }else{
        add_cache(src,dest,serialnumber);
      }
    
      if(me == src){
       // printf("received packet, I am source!\n");
       // printfflush();
      //call PacketAcknowledgements.requestAck(bufPtr);
      if(isNeighboor(dest)){
        call AMSend.send(dest,bufPtr,sizeof(BeaconMsg));
      }else{
        call AMSend.send(TOS_BCAST_ADDR,bufPtr,sizeof(BeaconMsg));  
      }
      
       
      }else if(me == dest){
        newserialnumber = bMsg->serialnumber;
       //printf("I am destination,received packet\n");
       // printfflush();
       stopb = (stop_bcast*) (payload);
       stopb->stop = STOP;
       //广播停止帧
       call AMSend.send(TOS_BCAST_ADDR,bufPtr,sizeof(stop_bcast));
      }else{
        
        //当概率大于某个值时才会进行广播
        probability = call Random.rand16();
        if(probability > threshold && !isStopBcast){
          if(isNeighboor(dest)){
            call AMSend.send(dest,bufPtr,sizeof(BeaconMsg));
          }else{
            call AMSend.send(TOS_BCAST_ADDR,bufPtr,sizeof(BeaconMsg));
          }
         
          printf("I am a middle one!\n");
          printfflush();
        }
      }
  }else if(len == sizeof(stop_bcast)){
    isStopBcast = TRUE;
  }
  
    return bufPtr;
  }
}

