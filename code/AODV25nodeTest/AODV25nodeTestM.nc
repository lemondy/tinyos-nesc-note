/*
 * Copyright (c) 2008 Junseok Kim
 * Author: Junseok Kim <jskim@usn.konkuk.ac.kr> <http://usn.konkuk.ac.kr/~jskim>
 * Date: 2008/05/30
 * Version: 0.0.1
 * Published under the terms of the GNU General Public License (GPLv2).
 */

#include "printf.h"
#include "Beacon.h"
#include "AODV.h"
module AODV25nodeTestM {
  uses {
    interface Boot;
    interface SplitControl;
    interface Timer<TMilli> as MilliTimer;
    interface AMSend;
    interface Receive;
    interface Leds;
  }
}

implementation {
  
  message_t pkt;
  message_t* p_pkt;
  
  uint16_t src  = 0x0001;
  uint16_t dest = 0x000a;
 //uint16_t src;
 //uint16_t dest;
 uint16_t serialnumber;

 //uint16_t counter = 0;
  
  event void Boot.booted() {
   
    call SplitControl.start();
  }
  
  
  event void SplitControl.startDone(error_t err) {
    if (err == SUCCESS) {
      //dbg("APPS", "%s\t APPS: startDone %d.\n", sim_time_string(), err);
     // pr("Apps:startDone %d.\n",sim_time_string(),err);
      p_pkt = &pkt;
      if( TOS_NODE_ID == src )
        call MilliTimer.startPeriodic(100);
    } else {
      call SplitControl.start();
    }

  }
  
  event void SplitControl.stopDone(error_t err) {
    // do nothing
  }
  
  
  event void MilliTimer.fired() {
    //dbg("APPS", "%s\t APPS: MilliTimer.fired()\n", sim_time_string());
   // pr("APPs:MilliTimer.fired()\n",sim_time_string());
   aodv_msg_hdr* aodv_msg =(aodv_msg_hdr*) (p_pkt->data);
    call Leds.led0Toggle();
    printf("fired!\n");
    printfflush();
    
    aodv_msg->dest = dest;
    aodv_msg->src = src;

    call AMSend.send(dest, p_pkt, 15);
    //pr("APPS:fired complete.");

  }
  
   // event void TimerTest.fired() {
    //pr("Counter= %d\n",counter);
  //}
  
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    dbg("APPS", "%s\t APPS: sendDone!!\n", sim_time_string());
    //pr("APPS:%s\t Apps: sendDone!!\n",sim_time_string());
    if( error ==  SUCCESS){
       printf("send done!\n");
       //printfflush();
    }else{
        printf("send failed!\n");
        //printfflush();
    }
   printf("fuck\n");
   printfflush();
  }
  
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
   // dbg("APPS", "%s\t APPS: receive!!\n", sim_time_string());
    //pr("Apps:%s\t Apps:receive!\n",sim_time_string());
    /*
    BeaconMsg* bMsg = (BeaconMsg*) payload;
    src = bMsg->nodeidi;
    dest = bMsg->nodeidk;
    serialnumber = bMsg->serialnumber;
    if(TOS_NODE_ID == src){
//      counter = 2;
      pr("Received: nodeidi:%d, nodeidk:%d, serialnumber:%d \n",src,dest,serialnumber);
      call AMSend.send(dest,bufPtr,14);
    }else if(TOS_NODE_ID == dest){
      pr("@@destination received: nodeidi:%d, nodeidk:%d, serialnumber:%d \n",src,dest,serialnumber);
    }else{
      pr("I'm just the middle one!");
      call AMSend.send(dest,bufPtr,14);
    }
    */
    aodv_msg_hdr* msgData = (aodv_msg_hdr*) payload;
   // pr("received: %u, %u, %u\n",msgData->dest,msgData->src,msgData->app);
   printf("received: %u, %u\n",msgData->dest,msgData->src);
   printfflush();
    return bufPtr;
  }
}

