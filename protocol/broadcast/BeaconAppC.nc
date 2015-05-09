#include <Timer.h>
#include "Beacon.h"
configuration BeaconAppC {
}
implementation {
  components MainC;
  components RandomC;
  components LedsC;
  components BeaconC as App;
  components new TimerMilliC() as Timer0;
  components ActiveMessageC;
  components new AMSenderC(AM_BEACON);

  App.Boot -> MainC;
  App.Leds -> LedsC;
  App.Random -> RandomC;
  App.Timer0 -> Timer0;
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.AMSend -> AMSenderC;
}
