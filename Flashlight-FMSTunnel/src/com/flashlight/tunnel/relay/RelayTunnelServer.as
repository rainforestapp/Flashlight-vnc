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
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	import mx.controls.Alert;
	import mx.logging.ILogger;
	import mx.logging.Log;

	public class RelayTunnelServer {
		private static const logger:ILogger = Log.getLogger("RelayTunnelServer");
		
		[Bindable] public var vncHost:String;
		[Bindable] public var vncPort:int;
		[Bindable] public var relayServerUrl:String;
		[Bindable] public var streamName:String;
		
		[Bindable] public var peerID:String;
		
		[Bindable] public var errorMessage:String;
		[Bindable] public var connected:Boolean = false;
		[Bindable] public var status:String = "Not connected";
		[Bindable] public var clients:int;
		
		private var relayConnection:NetConnection;
		private var relayStream:NetStream;
		
		private var handlers:Object = new Object();
		
		public function connect():void {
			logger.debug(">> connect()");
			
			if (connected) {
				errorMessage = "Already connected";
				return;
			}
			
			errorMessage = null;
			
			relayConnection = new NetConnection();
			relayConnection.addEventListener(AsyncErrorEvent.ASYNC_ERROR,onAsyncError);
			relayConnection.addEventListener(IOErrorEvent.IO_ERROR,onIOError);
			relayConnection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			relayConnection.addEventListener(NetStatusEvent.NET_STATUS,onRelayConnectionStatus);
			relayConnection.connect(relayServerUrl);
			logger.debug(relayServerUrl);
			
			status = "Connecting";
			connected = true;
			
			logger.debug("<< connect()");
		}
		
		public function disconnect():void {
			logger.debug(">> disconnect()");
			
			close();
			status = "Not connected";
			
			logger.debug("<< disconnect()");
		}
		
		private function onRelayConnectionStatus(event:NetStatusEvent):void {
			logger.debug(">> onRelayConnectionStatus()");
			
			switch (event.info.level) {
				case "status":
					logger.debug(event.info.code);
					switch (event.info.code) {
						case "NetConnection.Connect.Success":
							onRelayConnectionConnected();
							break;
						default:
							logger.debug(event.info.code);
					}
					break;
				case "error":
					onError(event.info.code);
					break;
			}
			
			logger.debug("<< onRelayConnectionStatus()");
		}
		
		private function onRelayConnectionConnected():void {
			logger.debug(">> onRelayConnectionConnected()");
			relayStream = new NetStream(relayConnection,NetStream.CONNECT_TO_FMS);
			relayStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			relayStream.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			relayStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
			relayStream.client = {
				requestConnection: function(streamName:String):void {
					onRequestConnection(streamName);
				}
			}
			relayStream.play(streamName);
			
			status = "Listening";
			logger.debug("<< onRelayConnectionConnected()");
		}
		
		private function onRequestConnection(streamName:String):void {
			logger.debug(">> onRequestConnection()");
			
			var handler:RelayClientHandler = new RelayClientHandler(vncHost,vncPort, relayConnection, streamName);
			handler.addEventListener(TunnelClientCloseEvent.TUNNEL_CLIENT_CLOSE,onTunnelClose);
			handler.addEventListener(TunnelClientErrorEvent.TUNNEL_CLIENT_ERROR,onTunnelError);
			handlers[streamName] = handler;
			clients++;
			
			logger.debug("<< onRequestConnection()");
		}
		
		private function onTunnelClose(event:TunnelClientCloseEvent):void {
			closeHandler((event.target as RelayClientHandler).streamName);
		}
		
		private function onTunnelError(event:TunnelClientErrorEvent):void {
			logger.error("Tunnel client error: "+event.message);
			closeHandler((event.target as RelayClientHandler).streamName);
		}
		
		private function closeHandler(streamName:String):void {
			logger.debug(">> closeHandler()");
			var handler:RelayClientHandler = handlers[streamName];
			delete handlers[streamName];
			handler.close();
			clients--;
			logger.debug("<< closeHandler()");
		}
		
		private function close():void {
			logger.debug(">> close()");
			for (var streamName:String in handlers) {
				closeHandler(streamName);
			}
			if (relayStream) {
				relayStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
				relayStream.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
				relayStream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
				relayStream.client = {};
				relayStream.close();
			}
			if (relayConnection) {
				relayConnection.removeEventListener(AsyncErrorEvent.ASYNC_ERROR,onAsyncError);
				relayConnection.removeEventListener(IOErrorEvent.IO_ERROR,onIOError);
				relayConnection.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				relayConnection.removeEventListener(NetStatusEvent.NET_STATUS,onRelayConnectionStatus);
				relayConnection.close();
			}
			connected = false;
			peerID = null;
			logger.debug("<< close()");
		}
		
		private function onNetStreamStatus(event:NetStatusEvent):void {
			logger.debug(">> onNetStreamStatus()");
			switch (event.info.level) {
				case "status":
					switch (event.info.code) {
						default:
							logger.debug(event.info.code);
					}
					break;
				case "error":
					onError(event.info.code);
					break;
			}
			logger.debug("<< onNetStreamStatus()");
		}
		
		private function onAsyncError(event:AsyncErrorEvent):void {
			onError(event.toString());
		}
		
		private function onIOError(event:IOErrorEvent):void {
			onError(event.toString());
		}
		
		private function onSecurityError(event:SecurityErrorEvent):void {
			onError(event.toString());
		}
		
		private function onError(message:String):void {
			status = "Error";
			errorMessage = message;
			logger.error(message);
			close();
		}
	}
}