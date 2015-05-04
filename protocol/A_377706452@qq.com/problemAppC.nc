#include "Beacon.h"

configuration problemAppC {
}
implementation {
  components MainC, problemA_M, LedsC,RandomC;
  components new AMSenderC(AM_BEACON);
  components new AMReceiverC(AM_BEACON);
  components new AMSenderC(HELLO_NEIGHBOOR) as SendHello;
  components new AMReceiverC(HELLO_NEIGHBOOR) as ReceiveHello ;
  components ActiveMessageC;
  
  problemA_M.Boot -> MainC.Boot;
  problemA_M.SplitControl -> ActiveMessageC;
  problemA_M.PacketAcknowledgements -> ActiveMessageC;

  problemA_M.AMSend -> AMSenderC;
  problemA_M.Receive -> AMReceiverC;
  problemA_M.SendHello -> SendHello;
  problemA_M.ReceiveHello -> ReceiveHello;

  problemA_M.Leds -> LedsC;
  problemA_M.AMPacket -> AMSenderC;
  problemA_M.Random -> RandomC;
  
  components new TimerMilliC() as OutTimer;

  problemA_M.OutTimer -> OutTimer;
}

