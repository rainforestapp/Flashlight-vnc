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

	public class P2PTunnelServer {
		private static const logger:ILogger = Log.getLogger("P2PTunnelServer");
		
		[Bindable] public var vncHost:String;
		[Bindable] public var vncPort:int;
		[Bindable] public var p2pServerUrl:String;
		
		[Bindable] public var peerID:String;
		
		[Bindable] public var errorMessage:String;
		[Bindable] public var connected:Boolean = false;
		[Bindable] public var status:String = "Not connected";
		[Bindable] public var clients:int;
		
		private var p2pConnection:NetConnection;
		private var p2pStream:NetStream;
		private var handlers:Dictionary = new Dictionary();
		
		public function connect():void {
			logger.debug(">> connect()");
			
			if (connected) {
				errorMessage = "Already connected";
				return;
			}
			
			errorMessage = null;
			
			p2pConnection = new NetConnection();
			p2pConnection.addEventListener(AsyncErrorEvent.ASYNC_ERROR,onAsyncError);
			p2pConnection.addEventListener(IOErrorEvent.IO_ERROR,onIOError);
			p2pConnection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			p2pConnection.addEventListener(NetStatusEvent.NET_STATUS,onP2PConnectionStatus);
			p2pConnection.connect(p2pServerUrl);
			
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
		
		private function onP2PConnectionStatus(event:NetStatusEvent):void {
			logger.debug(">> onP2PConnectionStatus()");
			
			switch (event.info.level) {
				case "status":
					logger.debug(event.info.code);
					switch (event.info.code) {
						case "NetConnection.Connect.Success":
							onP2PConnectionConnected();
						break;
						case "NetStream.Connect.Success":
							onP2PStreamConnected(event.info.stream);
						break;
						case "NetStream.Connect.Closed":
							onP2PStreamClose(event.info.stream);
						break;
						default:
							logger.debug(event.info.code);
					}
				break;
				case "error":
					onError(event.info.code);
				break;
			}
			
			logger.debug("<< onP2PConnectionStatus()");
		}
		
		private function onP2PConnectionConnected():void {
			logger.debug(">> onP2PConnectionConnected()");
			p2pStream = new NetStream(p2pConnection,NetStream.DIRECT_CONNECTIONS);
			p2pStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			p2pStream.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			p2pStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
			
			peerID = p2pConnection.nearID;
			status = "Listening";
			logger.debug("<< onP2PConnectionConnected()");
		}
		
		private function onP2PStreamConnected(netStream:NetStream):void {
			logger.debug(">> onP2PStreamConnected()");
			var handler:P2PClientHandler = new P2PClientHandler(vncHost,vncPort,netStream);
			handler.addEventListener(TunnelClientErrorEvent.TUNNEL_CLIENT_ERROR, onTunnelClientError);
			handler.addEventListener(TunnelClientCloseEvent.TUNNEL_CLIENT_CLOSE, onTunnelClose);
			handlers[netStream] = handler;
			
			clients++;
			logger.debug("<< onP2PStreamConnected()");
		}
		
		private function onP2PStreamClose(netStream:NetStream):void {
			logger.debug(">> onP2PStreamClose()");
			
			if (handlers[netStream]) {
				closeHandler(netStream);
			}
			logger.debug("<< onP2PStreamClose()");
		}
		
		private function onTunnelClientError(event:TunnelClientErrorEvent):void {
			logger.error("Tunnel client error: "+event.message);
			closeHandler(getHandlerStream(event.target as P2PClientHandler));
		}
		
		private function onTunnelClose(event:TunnelClientCloseEvent):void {
			logger.debug(">> onTunnelClose()");
			closeHandler(getHandlerStream(event.target as P2PClientHandler));
			logger.debug("<< onTunnelClose()");
		}
		
		private function closeHandler(netStream:NetStream):void {
			logger.debug(">> closeHandler()");
			var handler:P2PClientHandler = handlers[netStream];
			delete handlers[netStream];
			handler.close();
			clients--;
			logger.debug("<< closeHandler()");
		}
		
		private function getHandlerStream(handler:P2PClientHandler):NetStream {
			for (var stream:Object in handlers) {
				if (handlers[stream] == handler) return stream as NetStream;
			}
			return null;
		}
		
		private function close():void {
			logger.debug(">> close()");
			for (var netStream:Object in handlers) {
				closeHandler(netStream as NetStream);
			}
			if (p2pStream) {
				p2pStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
				p2pStream.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
				p2pStream.removeEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
				p2pStream.close();
			}
			if (p2pConnection) {
				p2pConnection.removeEventListener(AsyncErrorEvent.ASYNC_ERROR,onAsyncError);
				p2pConnection.removeEventListener(IOErrorEvent.IO_ERROR,onIOError);
				p2pConnection.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				p2pConnection.removeEventListener(NetStatusEvent.NET_STATUS,onP2PConnectionStatus);
				p2pConnection.close();
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