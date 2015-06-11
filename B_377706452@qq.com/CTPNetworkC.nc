#include <Timer.h>
#include "CTPNetwork.h"
#include "printf.h"

module CTPNetworkC {
  uses interface Boot;
  uses interface Leds;

  uses interface SplitControl as RadioControl;
  uses interface SplitControl as SerialControl;
  uses interface Receive as AMReceive;
  uses interface AMSend as UARTSend;
  uses interface Packet;

  uses interface StdControl as RoutingControl;
  uses interface RootControl;
  uses interface Send as CtpSend;  
  uses interface Receive as CtpReceive;
  uses interface CollectionPacket;
  uses interface CtpPacket;
  uses interface CtpInfo;
  uses interface CtpCongestion;

  uses interface Timer<TMilli> as Timer0;

  //
  //uses interface LowPowerListening as Lpl;
  //

  uses interface Queue<message_t*>;
  uses interface Pool<message_t>;

}

implementation {

  task void uartEchoTask();
  message_t ctp_pkt;
  message_t uart_pkt;
  bool CtpSendBusy = FALSE;
  bool uartbusy = FALSE;
  typedef nx_struct BeaconMsg {
    nx_uint16_t nodeid;
    nx_uint8_t data[28];
  }BeaconMsg;
  BeaconMsg buff[50];
  uint16_t read = 0;
  uint16_t write = 0;
  uint16_t old = 0;

  event void Boot.booted() {
    call SerialControl.start();
  }
  event void SerialControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call SerialControl.start();
    }else{
      call RadioControl.start();
    }
  }
  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call RadioControl.start();
    }else {
      call RoutingControl.start();
      if (TOS_NODE_ID==0) {
	call RootControl.setRoot();
  call Timer0.startPeriodic(70);
 // call Lpl.setLocalWakeupInterval(0);
      }
    }
  }

  event void RadioControl.stopDone(error_t err) {}
  event void SerialControl.stopDone(error_t err) {}	

 event message_t* AMReceive.receive(message_t* msg, void* p, uint8_t len) {

    if (len == sizeof(CTPNetworkMsg_t)){      
       CTPNetworkMsg_t* radio_payload = (CTPNetworkMsg_t*)p;
       CTPNetworkMsg_t* ctp_msg = (CTPNetworkMsg_t*)call CtpSend.getPayload(&ctp_pkt, sizeof(CTPNetworkMsg_t));

       memcpy(ctp_msg,p,len);
       if(ctp_msg->nodeid != old) {
           if(!CtpSendBusy){

              if (call CtpSend.send(&ctp_pkt, sizeof(CTPNetworkMsg_t)) != SUCCESS){
               call Leds.led0Toggle();
               } else{
              CtpSendBusy = TRUE;
              }
           }
           old = ctp_msg->nodeid;
      }
    }
    return msg;
  }

  event void CtpSend.sendDone(message_t* m, error_t err) {
    if (err != SUCCESS) {
      call Leds.led0Toggle();
    }else{
    }
    CtpSendBusy = FALSE;
  }
  

  event message_t* CtpReceive.receive(message_t* msg, void* payload, uint8_t len) {

    if(len == sizeof(CTPNetworkMsg_t))
    {
       CTPNetworkMsg_t* ctp_payload = (CTPNetworkMsg_t*)payload;
       CTPNetworkMsg_t* uart_msg = (CTPNetworkMsg_t*)call UARTSend.getPayload(&uart_pkt, sizeof(CTPNetworkMsg_t));

        uint8_t i;
        uint8_t judge = 0;
        if(judge == 0) {
            buff[write].nodeid = ctp_payload->nodeid;
            for(i = 0; i < 28; i++) {
                buff[write].data[i] = ctp_payload->data[i];
            }
            write++;
            if(write >= 50) {
                write = 0;
            }
        }
    }

    return msg;
 }

 event void Timer0.fired(){

   
   if(read != write) {
       uint8_t i;
       printf("GreenOrbs %x %x",buff[read].nodeid/256,buff[read].nodeid%256);
       for(i = 0; i < 28; i++){
          printf(" %x",buff[read].data[i]);
       }
       printf("\n");
       printfflush(); 
       read++;
       if(read >= 50) {
          read = 0;
       }
   }
 }











 task void uartEchoTask() {
  uint8_t i;
   if (call Queue.empty()) {
     return;
   }
   else {
       message_t* msg = call Queue.dequeue();
       CTPNetworkMsg_t* temp_msg = (CTPNetworkMsg_t*)call Packet.getPayload(msg, sizeof(CTPNetworkMsg_t));
       printf("GreenOrbs %x %x",temp_msg->nodeid/256,temp_msg->nodeid%256);
       for(i = 0; i < 28; i++){
        printf(" %x",temp_msg->data[i]);
       }
       printf("\n");
       printfflush(); 
        
	   //call Pool.put(msg);
       if (!call Queue.empty()) {
         post uartEchoTask();
       } 
       call Leds.led1Toggle();
   }
 }

  event void UARTSend.sendDone(message_t *msg, error_t error) {} 

}
