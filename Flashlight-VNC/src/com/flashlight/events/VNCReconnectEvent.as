package com.flashlight.events
{
	public class VNCReconnectEvent extends VNCEvent
	{
		public static const RECONNECTING:String = 'reconnecting';
		
		public static const TIMER_STARTS:String = 'timerStarts';
		
		public static const SUCCESSFULLY_RECONNECTED:String = 'successfullyConnected';
		
		public function VNCReconnectEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
	}
}