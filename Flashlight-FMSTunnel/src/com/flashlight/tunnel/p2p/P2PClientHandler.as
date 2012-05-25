/*

Copyright (C) 2011 Marco Fucci

This program is free software; you can redistribute it and/or modify it under the terms of the
GNU General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program;
if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

Contact : mfucci@gmail.com

*/

package com.flashlight.tunnel.p2p
{
	import com.flashlight.tunnel.events.TunnelClientCloseEvent;
	import com.flashlight.tunnel.events.TunnelClientErrorEvent;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	[Event(name="tunnelClientClose", type="com.flashlight.tunnel.events.TunnelClientCloseEvent")]
	[Event(name="tunnelClientError", type="com.flashlight.tunnel.events.TunnelClientErrorEvent")]
	
	public class P2PClientHandler extends EventDispatcher {
		private static const logger:ILogger = Log.getLogger("P2PClientHandler");
		
		private var socket:Socket;
		private var stream:NetStream;
		
		// RTMFP bugfix: if a peak of data is sent followed by inactivity, data get stuck into the transmit buffer
		private var keepAliveTimer:Timer;
		
		private var packetId:uint = 0;
		
		public function P2PClientHandler(vncHost:String, vncPort:int, stream:NetStream) {
			logger.debug(">> P2PClientHandler()");
			
			this.stream = stream;
			stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			stream.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			stream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			stream.client = {
				onData: function(packetId:uint, data:ByteArray):void {
					//logger.debug(">> onData()");
					if (data.length > 0) {
						socket.writeBytes(data);
						socket.flush();
					}
					//logger.debug("<< onData()");
				}
			}
			
			socket = new Socket();
			socket.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
			socket.addEventListener(Event.CLOSE,onSocketClose);
			socket.connect(vncHost,vncPort);
			
			keepAliveTimer = new Timer(100);
			keepAliveTimer.addEventListener(TimerEvent.TIMER, onKeepAliveTimerTimer);
			
			logger.debug("<< P2PClientHandler()");
		}
		
		private function onKeepAliveTimerTimer(event:TimerEvent):void {
			stream.send("onData",0,new ByteArray());
		}
		
		private function onSocketData(event:ProgressEvent = null):void {
			//logger.debug(">> onSocketData()");
			
			var data:ByteArray = new ByteArray();
			socket.readBytes(data,0,socket.bytesAvailable);
			stream.send("onData",packetId,data);
			packetId++;
			keepAliveTimer.reset();
			keepAliveTimer.start();
			
			//logger.debug("<< onSocketData()");
		}
		
		private function onSocketClose(event:Event):void {
			logger.debug(">> onSocketClose()");
			close();
			dispatchEvent(new TunnelClientCloseEvent());
			logger.debug("<< onSocketClose()");
		}
		
		public function close():void {
			logger.debug(">> close()");
			
			if (socket) {
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
				socket.removeEventListener(Event.CLOSE,onSocketClose);
				socket.close();
			}
			if (stream) {
				stream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
				stream.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
				stream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
				stream.client = {};
				stream.close();
			}
			keepAliveTimer.addEventListener(TimerEvent.TIMER,onKeepAliveTimerTimer);
			keepAliveTimer.stop();
			keepAliveTimer = null;
			socket = null;
			stream = null;
			
			logger.debug("<< close()");
		}
		
		private function onNetStatus(event:NetStatusEvent):void {
			logger.debug(">> onNetStatus()");
			switch (event.info.level) {
				case "status":
					switch (event.info.code) {
						default:
							logger.debug(event.info.code);
					}
					break;
				case "error":
					dispatchEvent(new TunnelClientErrorEvent(event.info.code));
					close();
					break;
			}
			logger.debug("<< onNetStatus()");
		}
		
		private function onAsyncError(event:AsyncErrorEvent):void {
			dispatchEvent(new TunnelClientErrorEvent(event.toString()));
			close();
		}
		
		private function onIOError(event:IOErrorEvent):void {
			dispatchEvent(new TunnelClientErrorEvent(event.toString()));
			close();
		}
		
		private function onSecurityError(event:SecurityErrorEvent):void {
			dispatchEvent(new TunnelClientErrorEvent(event.toString()));
			close();
		}
	}
}