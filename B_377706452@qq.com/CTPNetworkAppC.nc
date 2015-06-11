#include "CTPNetwork.h"
#include "Ctp.h"
configuration CTPNetworkAppC {}
implementation {
  components CTPNetworkC, MainC, LedsC;

  components ActiveMessageC;
  components SerialActiveMessageC;
  components new AMReceiverC(AM_BEACON);
  components new SerialAMSenderC(AM_BEACON);

  components CollectionC as Collector;
  components new CollectionSenderC(COLLECTION_ID);   

  components new QueueC(message_t*, 30);
  components new PoolC(message_t, 30);

  components new TimerMilliC() as Timer0;

  CTPNetworkC.Boot -> MainC;
  CTPNetworkC.Leds -> LedsC;
  CTPNetworkC.RadioControl -> ActiveMessageC;
  CTPNetworkC.SerialControl -> SerialActiveMessageC;
  CTPNetworkC.AMReceive -> AMReceiverC.Receive;
  CTPNetworkC.UARTSend -> SerialAMSenderC.AMSend;
  CTPNetworkC.Packet -> SerialAMSenderC;

  CTPNetworkC.RoutingControl -> Collector;
  CTPNetworkC.RootControl -> Collector;
  CTPNetworkC.CtpSend -> CollectionSenderC.Send;
  CTPNetworkC.CtpReceive -> Collector.Receive[COLLECTION_ID];
  CTPNetworkC.CollectionPacket -> Collector;
  CTPNetworkC.CtpPacket -> Collector;
  CTPNetworkC.CtpInfo -> Collector;
  CTPNetworkC.CtpCongestion -> Collector;

  CTPNetworkC.Timer0 -> Timer0;

//
//  CTPNetworkC.Lpl -> ActiveMessageC;
//

  CTPNetworkC.Pool -> PoolC;
  CTPNetworkC.Queue -> QueueC;
}
