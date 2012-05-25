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

package com.flashlight.tunnel.relay
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
	
	public class RelayClientHandler extends EventDispatcher {
		private static const logger:ILogger = Log.getLogger("RelayClientHandler");
		
		private var socket:Socket;
		private var netConnection:NetConnection;
		private var downStream:NetStream;
		private var upStream:NetStream;
		private var vncHost:String;
		private var vncPort:int;
		private var timeoutTimer:Timer;
		
		public var streamName:String;
		
		public function RelayClientHandler(vncHost:String, vncPort:int, netConnection:NetConnection, streamName:String) {
			logger.debug(">> RelayClientHandler()");
			
			this.vncHost = vncHost;
			this.vncPort = vncPort;
			this.streamName = streamName;
			downStream = new NetStream(netConnection);
			downStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			downStream.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			downStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			downStream.client = {
				onData: function(data:ByteArray):void {
					//logger.debug(">> onData()");
					//logger.info("<< in "+data.length);
					socket.writeBytes(data);
					socket.flush();
					//logger.debug("<< onData()");
				}
			}
			downStream.play(streamName+"_c2s");
			
			upStream = new NetStream(netConnection);
			upStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			upStream.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			upStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			upStream.publish(streamName+"_s2c");
			
			timeoutTimer = new Timer(3000,1);
			timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE,onTimeout);
			timeoutTimer.start();
			
			logger.debug("<< RelayClientHandler()");
		}
		
		private function onSocketData(event:ProgressEvent):void {
			//logger.debug(">> onSocketData()");
			
			var data:ByteArray = new ByteArray();
			socket.readBytes(data,0,socket.bytesAvailable);
			//logger.info(">> out "+data.length);
			upStream.send("onData",data);
			
			//logger.debug("<< onSocketData()");
		}
		
		private function onSocketClose(event:Event):void {
			logger.debug(">> onSocketClose()");
			close();
			dispatchEvent(new TunnelClientCloseEvent());
			logger.debug("<< onSocketClose()");
		}
		
		private function onTimeout(event:TimerEvent):void {
			logger.debug(">> onTimeout()");
			
			dispatchEvent(new TunnelClientErrorEvent("Connection timeout"));
			close();
			
			logger.debug("<< onTimeout()");
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
			if (upStream) {
				upStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
				upStream.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
				upStream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
				upStream.client = {};
				upStream.close();
			}
			if (downStream) {
				downStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
				downStream.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
				downStream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
				downStream.client = {};
				downStream.close();
			}
			if (timeoutTimer) {
				timeoutTimer.stop();
				timeoutTimer.removeEventListener(TimerEvent.TIMER_COMPLETE,onTimeout);
			}
			timeoutTimer = null;
			socket = null;
			upStream = null;
			downStream = null;
			
			logger.debug("<< close()");
		}
		
		private function onNetStatus(event:NetStatusEvent):void {
			logger.debug(">> onNetStatus()");
			switch (event.info.level) {
				case "status":
					switch (event.info.code) {
						case "NetStream.Publish.Start":
							socket = new Socket();
							socket.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
							socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
							socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
							socket.addEventListener(Event.CLOSE,onSocketClose);
							socket.connect(vncHost,vncPort);
							timeoutTimer.reset();
							timeoutTimer.removeEventListener(TimerEvent.TIMER_COMPLETE,onTimeout);
							timeoutTimer = null;
							break;
						case "NetStream.Play.UnpublishNotify":
							close();
							dispatchEvent(new TunnelClientCloseEvent());
							break;
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