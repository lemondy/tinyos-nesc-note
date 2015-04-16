
module BlinkC{
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as Timer0;
	uses interface SplitControl as AMControl;

}implementation{

	int8_t count = 0;
	event void Boot.boot(){
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err){
		if(err == SUCCESS){
			call Timer0.startPeriodic(1000);
		}else{
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err){

	}

	event void Timer0.fired(){
		if( count & 1){
			call Leds.led0On();
		}else{
			call leds.led0Off();
		}

		if(count & 2){
			call Leds.led1On();
		}else{
			call Leds.led1Off();
		}

		if(count & 4){
			call Leds.led2On();
		}else{
			call Leds.led2Off();
		}

		count++;
		count %= 8;

	}

}
