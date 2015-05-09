#include "printf.h"
#include "Beacon.h"

module problemA_M {
  uses {
    interface Boot;
    interface SplitControl;
    interface Timer<TMilli> as OutTimer;    
    interface Timer<TMilli> as HelloTimer;
    interface Timer<TMilli> as MessageTimer;
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
 //消息队列，记录本节点要发送的消息
 message_t* msgQueue[QUEUE_SIZE];

 uint8_t head,tail;
 uint16_t src;
 uint16_t dest;
 uint16_t serialnumber;
 uint16_t oldserialnumber = 0;
 uint16_t newserialnumber = 0;
 uint16_t threshold = (0xffff / 5);
 uint16_t probability = 0;

//cache只是记录已经发送过的帧，防止重复，形成环
 BeaconMsg cache_table[CACHE_SIZE];
 neighboor_node_table neighboor_table[NEIGHBOOR_SIZE];
 
 //当目的节点接收到数据包时向邻居节点发送终止消息，邻居节点不会继续广播
 stop_bcast* stopb;

 bool busy = FALSE;
 bool isStopBcast = FALSE;

 uint16_t i;
 uint16_t j;
 uint8_t k;

 void sendHello(am_addr_t addr);
 bool forwardMsg(am_addr_t addr,message_t* msg);

 bool enQueue(message_t* msg);
 message_t* deQueue();
 bool isQueueFull();
 bool isQueueEmpty();
  
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

    head=tail=0;

    for(i=0; i < NEIGHBOOR_SIZE; i++){
      neighboor_table[i].neighboor = INVALIDATE_NODE_ID;
    }

  }

  void sendHello(am_addr_t addr){
    send_hello* sendhello = (send_hello*) (p_pkt->data);
    sendhello->hello = HELLO;

    call SendHello.send(addr,p_pkt,sizeof(send_hello));
  }
  
  event void SplitControl.startDone(error_t err) {
    uint8_t startTime = call Random.rand16() % 9; //控制发送hello的起始时间
    if (startTime == 0) startTime = 1;

    if (err == SUCCESS) {
      p_pkt = &pkt;
      call OutTimer.startPeriodic(50);
      call HelloTimer.startOneShot(startTime * 1000);  //这里要设置时间在10秒内
      call MessageTimer.startPeriodic(100);   //定期扫描
    } else {
      call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err) {}

  bool isCached(am_addr_t src,am_addr_t dest){
    for(i=0;i<CACHE_SIZE;i++){
      if((cache_table[i].nodeidi == src ) && (cache_table[i].nodeidk == dest))
        return TRUE;
    }
    return FALSE;
  }
 
  void add_cache(am_addr_t src,am_addr_t dest, uint16_t serialnumber){
    cache_table[j].nodeidi = src;
    cache_table[j].nodeidk = dest;
    cache_table[j].serialnumber = serialnumber;
    j++; 
  }

 void add_neighboor(am_addr_t id){
  neighboor_table[k].neighboor = id;
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

 bool isQueueFull(){
  if(head == (tail+1)%QUEUE_SIZE){
    return TRUE;
  }
  return FALSE;
 }

 bool isQueueEmpty(){
  if(head == tail)
    return TRUE;
  return FALSE;
 }

 bool enQueue(message_t* msg){
  if(!isQueueFull()){
    msgQueue[tail] = msg;
    tail = (tail + 1) % QUEUE_SIZE;
    return TRUE;
    }
  return FALSE;
  }

//出队得到的元素要判断下是否为NULL
message_t* deQueue(){
  message_t* message;
  if(!isQueueEmpty()){
    message = msgQueue[head];
    head = (head+1) % QUEUE_SIZE;
  }
  return message;
}
event void OutTimer.fired(){
  if((newserialnumber - oldserialnumber) != 0){
    printf("GreenOrbs  %x\n",newserialnumber);
    printfflush();
    oldserialnumber = newserialnumber;
  }
}

  event void HelloTimer.fired(){
     //初始时每个节点广播一个hello帧
    sendHello(TOS_BCAST_ADDR);
  }

  //扫描消息队列 
  event void MessageTimer.fired(){
    BeaconMsg* msg = (BeaconMsg*) p_pkt -> data;
    if(!isQueueEmpty()){
      if(!busy){
        p_pkt = deQueue();
        
        dest = msg->nodeidk;
        forwardMsg(dest,p_pkt);
        busy = TRUE;
      }
    }
  }

  bool forwardMsg(am_addr_t addr,message_t* msg){
    if(isNeighboor(addr)){ //若存在邻居表中，直接发送
      call AMSend.send(dest,msg,sizeof(BeaconMsg));
    }else{
      call AMSend.send(TOS_BCAST_ADDR,msg,sizeof(BeaconMsg));  
    }
  }

  event message_t* ReceiveHello.receive(message_t* msg, void* payload, uint8_t len){
    if(len == sizeof(send_hello)){
      send_hello* receiveHello_msg = (send_hello*) payload;
      am_addr_t src = call AMPacket.source(msg);

      if(receiveHello_msg->hello == HELLO){
          add_neighboor(src);  //接收到邻居发来的hello帧，添加到邻居表中
      } 
    }

    return msg;
  }
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
   
   if(len == sizeof(BeaconMsg)){
      BeaconMsg* bMsg = (BeaconMsg*) payload;
      am_addr_t me = call AMPacket.address();
      src = bMsg->nodeidi;
      dest = bMsg->nodeidk;
      serialnumber = bMsg->serialnumber;

      if(isCached(src,dest)){  //如果消息已经接收过，再次接收不做任何处理
          return bufPtr; 
      }else{
        add_cache(src,dest,serialnumber); 
      }

      if(me == src){

        if(!busy){
          forwardMsg(dest,bufPtr);
          busy = TRUE;
        }else{  //发送未完成，入队稍后发送
          enQueue(bufPtr);
        }
      
      }else if(me == dest){
        newserialnumber = bMsg->serialnumber;
        stopb = (stop_bcast*) (bufPtr->data);
        stopb->stop = STOP;
       //广播停止帧
       call AMSend.send(TOS_BCAST_ADDR,bufPtr,sizeof(stop_bcast));
      }else{
        
        //当概率大于某个值时才会进行广播
        probability = call Random.rand16();
       if(probability > threshold && !isStopBcast){

          if(!busy){
           forwardMsg(dest,bufPtr);
           busy = TRUE;
         }else{
            enQueue(bufPtr);
         }
 
        }
      }
  }else if(len == sizeof(stop_bcast)){
    isStopBcast = TRUE;  
  }
    return bufPtr;
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    busy = FALSE;
  }

  event void SendHello.sendDone(message_t* msg, error_t err){}
}

