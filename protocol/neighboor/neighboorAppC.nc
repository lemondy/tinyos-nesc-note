#include "Beacon.h"

configuration neighboorAppC {
}
implementation {
  components MainC, neighboorM,RandomC;
  components new AMSenderC(HELLO_NEIGHBOOR) as SendHello;
  components new AMReceiverC(HELLO_NEIGHBOOR) as ReceiveHello ;
  components ActiveMessageC;
  components new TimerMilliC() as Timer;
  components new TimerMilliC() as Timer1;


  neighboorM.Timer -> Timer;
  neighboorM.Timer1 -> Timer1;
  
  neighboorM.Boot -> MainC.Boot;
  neighboorM.SplitControl -> ActiveMessageC;


  neighboorM.SendHello -> SendHello;
  neighboorM.ReceiveHello -> ReceiveHello;

  neighboorM.AMPacket -> SendHello;
  neighboorM.Random -> RandomC;

  
}

