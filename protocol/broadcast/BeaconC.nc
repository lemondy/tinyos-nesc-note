/*********************************************************
*          第二届全国高校物联网创新应用大赛
*          编程挑战赛预赛数据源节点样例程序
*             
*                     A题
*
*  发包个数：1176    间隔：60ms   总耗时：70560ms
*
*********************************************************/

#include <Timer.h>
#include "Beacon.h"
module BeaconC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface SplitControl as AMControl;
  
  uses interface Random;
}

implementation {

  uint16_t counter;
  message_t pkt;
  bool busy = FALSE;
  
  uint16_t nodei=1;
  uint16_t nodek=2;
  uint16_t serialnum=1;  

  event void Boot.booted() {
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer0.startPeriodic( 60 );
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }

  event void Timer0.fired() {
             
	if (!busy) {
        BeaconMsg* btrpkt = (BeaconMsg*)(call Packet.getPayload(&pkt, sizeof(BeaconMsg)));
      	if (btrpkt == NULL) {
          return;
      	}
      	btrpkt->nodeidi = nodei;   //包负载携带节点i的ID
      	btrpkt->nodeidk = nodek;   //包负载携带节点k的ID
        btrpkt->serialnumber = serialnum;  //包负载携带任务包编号      
    	
      	if (call AMSend.send(nodei, &pkt, sizeof(BeaconMsg)) == SUCCESS) {  
          busy = TRUE;
        }

        nodek++;
		serialnum++;
 
        if(nodek ==50){
            nodei++;
            nodek = nodei + 1;
            
            if(nodei==49){
				call Timer0.stop();		
			}
		}
	}
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (&pkt == msg) {
      busy = FALSE;
      call Leds.led0Toggle();
    }
  
  }

}
