
#include "PDV.h"



configuration PDV {
  provides {
    interface SplitControl;
    interface AMSend[am_id_t id];
    interface Receive[uint8_t id];
  }
  uses {
    ;
  }
}

implementation {
  components PDV_M, RandomC, ActiveMessageC;
  
  SplitControl = PDV_M.SplitControl;
  AMSend = PDV_M.AMSend;
  Receive = PDV_M.Receive;
  
  PDV_M.Random -> RandomC;
  PDV_M.AMPacket -> ActiveMessageC;
  PDV_M.Packet -> ActiveMessageC;
  PDV_M.PacketAcknowledgements -> ActiveMessageC;
  PDV_M.AMControl -> ActiveMessageC.SplitControl;
  
  components new AMSenderC(AM_PDV_HELLO) as MHSendHELLO,
             new AMSenderC(AM_PDV_RREQ) as MHSendRREQ, 
             new AMSenderC(AM_PDV_RREP) as MHSendRREP, 
             new AMSenderC(AM_PDV_RERR) as MHSendRERR;

  PDV_M.SendHELLO -> MHSendHELLO;
  PDV_M.SendRREQ -> MHSendRREQ;
  PDV_M.SendRREP -> MHSendRREP;
  PDV_M.SendRERR -> MHSendRERR;
  
  components new AMSenderC(AM_PDV_MSG) as MHSend;
  PDV_M.SubSend -> MHSend;
  
  components new AMReceiverC(AM_PDV_HELLO) as MHReceiveHELLO;
             new AMReceiverC(AM_PDV_RREQ) as MHReceiveRREQ, 
             new AMReceiverC(AM_PDV_RREP) as MHReceiveRREP, 
             new AMReceiverC(AM_PDV_RERR) as MHReceiveRERR;

  PDV_M.ReceiveHELLO -> MH$ReceiveHELLO;
  PDV_M.ReceiveRREQ -> MHReceiveRREQ;
  PDV_M.ReceiveRREP -> MHReceiveRREP;
  PDV_M.ReceiveRERR -> MHReceiveRERR;
  
  components new AMReceiverC(AM_PDV_MSG) as MHReceive;
  PDV_M.SubReceive -> MHReceive;
  
  components new TimerMilliC() as PDV_Timer;
  PDV_M.PDVTimer -> PDV_Timer;
  
  components new TimerMilliC() as RREQ_Timer;
  PDV_M.RREQTimer -> RREQ_Timer;
  
}

