
#include "printf.h"
#include "Beacon.h"

module neighboorM {
  uses {
    interface Boot;
    interface SplitControl;  
    interface AMSend as SendHello;
    interface Receive as ReceiveHello;
    interface AMPacket;
    interface Random;
    interface Timer<TMilli> as Timer;
    interface Timer<TMilli> as Timer1;

  }
}

implementation {
  
  message_t pkt;
  message_t* p_pkt;
  

 neighboor_node_table neighboor_table[NEIGHBOOR_SIZE];

 uint16_t i;
 uint16_t newcounter = 0;
 uint16_t oldcounter = 0;
 uint8_t j=0;
 uint8_t k;

 void sendHello(am_addr_t addr);
  
  event void Boot.booted() {
   
    call SplitControl.start();


   //指向本地缓存中有效位置,发送一个广播帧之后，j自增，记录已经发送过的包
    

    k = 0;

    for(i=0; i < NEIGHBOOR_SIZE; i++){
      neighboor_table[i].neighboor = INVALIDATE_NODE_ID;
    }


    //初始时每个节点广播一个hello帧
    
  }
  

  void sendHello(am_addr_t addr){
    send_hello* sendhello = (send_hello*) (p_pkt->data);
    sendhello->hello = HELLO;

    call SendHello.send(addr,p_pkt,sizeof(send_hello));
  }

  event void Timer1.fired(){
    sendHello(TOS_BCAST_ADDR);
  }
  event void Timer.fired(){
    //if((newcounter - oldcounter) != 0){
    //printf("fired");
   // printf("Random:%x\n",(call Random.rand16() % 7));
      for(;j<=k;j++){
        printf("neighboor:%x\n",neighboor_table[j]);
        printfflush();
      }
      j=0;
      //j--;
     // oldcounter = newcounter;

   // }
  }
  
  event void SplitControl.startDone(error_t err) {
    uint8_t timer = call Random.rand16() % 9;
    if (err == SUCCESS) {
      p_pkt = &pkt;
     // call OutTimer.startPeriodic(50);   
     call Timer.startPeriodic(5000);
     call Timer1.startOneShot(timer * 1000);
    } else {
      call SplitControl.start();
    }

  }
  

 void add_neighboor(am_addr_t id){
  neighboor_table[k].neighboor = id;
  k++;
 }

 
  event void SplitControl.stopDone(error_t err) {
    // do nothing
  }
  


  event void SendHello.sendDone(message_t* msg, error_t err){}

  event message_t* ReceiveHello.receive(message_t* msg, void* payload, uint8_t len){
    if(len == sizeof(send_hello)){
      send_hello* receiveHello_msg = (send_hello*) payload;
      am_addr_t me = call AMPacket.address();
      am_addr_t src = call AMPacket.source(msg);

      if(receiveHello_msg->hello == HELLO){
          add_neighboor(src);
          newcounter++;

          //sendHello(src);
      } 
    }
    return msg;
  }
  

}

