package com.flashlight.events
{
	import flash.events.Event;
	
	public class VNCEvent extends Event
	{
		public function VNCEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
	}
}