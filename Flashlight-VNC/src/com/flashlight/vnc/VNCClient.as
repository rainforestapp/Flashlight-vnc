/*

Copyright (C) 2009 Marco Fucci

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

package com.flashlight.vnc
{
	import com.flashlight.crypt.DesCipher;
	import com.flashlight.pixelformats.RFBPixelFormat;
	import com.flashlight.pixelformats.RFBPixelFormat16bpp;
	import com.flashlight.pixelformats.RFBPixelFormat16bppLittleEndian;
	import com.flashlight.pixelformats.RFBPixelFormat32bpp;
	import com.flashlight.pixelformats.RFBPixelFormat32bppLittleEndian;
	import com.flashlight.pixelformats.RFBPixelFormat8bpp;
	import com.flashlight.rfb.RFBReader;
	import com.flashlight.rfb.RFBReaderError;
	import com.flashlight.rfb.RFBReaderListener;
	import com.flashlight.rfb.RFBWriter;
	import com.flashlight.utils.BetterSocket;
	import com.flashlight.utils.IDataBufferedOutput;
	import com.flashright.RightMouseEvent;
	
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TextEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.Socket;
	import flash.system.Security;
	import flash.ui.Keyboard;
	import flash.ui.Mouse;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import mx.binding.utils.ChangeWatcher;
	import mx.controls.Alert;
	import mx.core.Application;
	import mx.events.PropertyChangeEvent;
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	[Event( name="vncError", type="com.flashlight.vnc.VNCErrorEvent" )]
	[Event( name="vncRemoteCursor", type="com.flashlight.vnc.VNCRemoteCursorEvent" )]
	[Event( name="vncPasswordRequiered", type="com.flashlight.vnc.VNCPasswordRequieredEvent" )]
	
	public class VNCClient extends EventDispatcher implements RFBReaderListener {
		private static var logger:ILogger = Log.getLogger("VNCClient");
		
		private var socket:Socket;
		private var rfbReader:RFBReader;
		private var rfbWriter:RFBWriter;
		
		private var nativeColorBigEndian:Boolean;
		
		private var vncAuthChallenge:ByteArray;
		
		private var pixelFormats:Object = {
			"8": new RFBPixelFormat8bpp(),
			"16": new RFBPixelFormat16bpp(),
			"24": new RFBPixelFormat32bpp()
		};
		
		private var pixelFormatsLowEndian:Object = {
			"8": new RFBPixelFormat8bpp(),
			"16": new RFBPixelFormat16bppLittleEndian(),
			"24": new RFBPixelFormat32bppLittleEndian()
		};
		
		private var pixelFormatChangePending:Boolean = false;
		private var disableRemoteMouseEvents:Boolean = false;
		private var updateRectangle:Rectangle;
		private var testingStatus:String = VNCConst.TEST_CONNECTION_DISABLED;
		
		[Bindable] public var host:String = 'localhost';
		[Bindable] public var port:int = 5900;
		[Bindable] public var securityPort:int = 0;
		[Bindable] public var shareConnection:Boolean = true;
		[Bindable] public var password:String;
		
		[Bindable] public var serverName:String;
		[Bindable] public var screen:VNCScreen;
		
		[Bindable] public var status:String = VNCConst.STATUS_NOT_CONNECTED;
		
		[Bindable] public var viewOnly:Boolean;
		[Bindable] public var useRemoteCursor:Boolean;
		
		[Bindable] public var encoding:int;
		[Bindable] public var jpegCompression:int;
		[Bindable] public var colorDepth:int;
		[Bindable] public var updateRectangleSettings:Rectangle;
		[Bindable] public var framebufferHasOffset:Boolean;
		
		[Bindable] public var reConnect:Boolean;
		
		
		
		//Timer 
		public var timer:Timer = new Timer(6000);
		
		public function VNCClient() {
			ChangeWatcher.watch(this,"colorDepth",onColorDepthChange);
			ChangeWatcher.watch(this,"encoding",onEncodingChange);
			ChangeWatcher.watch(this,"jpegCompression",onJpegCompressionChange);
			ChangeWatcher.watch(this,"viewOnly",onViewOnlyChange);
		}
		
		public function connect():void {
			if (status !== VNCConst.STATUS_NOT_CONNECTED) disconnect();
			
			if (securityPort) Security.loadPolicyFile("xmlsocket://"+host+":"+securityPort);
			
			socket = new BetterSocket();
			
			socket.addEventListener(Event.CONNECT, onSocketConnect,false,0,true);
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData,false,0,true);
			socket.addEventListener(Event.CLOSE, onSocketClose,false,0,true);
			socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketSecurityError,false,0,true);
			socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError,false,0,true);
			
			socket.connect(host,port);
			
			status = VNCConst.STATUS_CONNECTING;
		}
		
		public function onRFBVersion(serverRfbMajorVersion:Number, serverRfbMinorVersion:Number):void {
			var majorVersion:Number = Math.min(serverRfbMajorVersion, VNCConst.RFB_VERSION_MAJOR);
			var minorVersion:Number = Math.min(serverRfbMinorVersion, VNCConst.RFB_VERSION_MINOR);
			
			rfbReader.setRFBVersion(majorVersion, minorVersion);
			rfbWriter = new RFBWriter(IDataBufferedOutput(socket), majorVersion, minorVersion);
			rfbWriter.writeRFBVersion(majorVersion, minorVersion);
			
			logger.info("RFB procotol version "+serverRfbMajorVersion+"."+serverRfbMinorVersion);
			
			status = VNCConst.STATUS_INITIATING;
		}
		
		public function onSecurityTypes(securityTypes:Array):void {
			var preferredSecurityType:uint = 0;
			for each (var securityTypeClient:uint in VNCConst.SECURITY_TYPE_PREFERRED_ORDER) {
				for each (var securityTypeServer:uint in securityTypes) {
					if (securityTypeClient == securityTypeServer) {
						preferredSecurityType = securityTypeClient;
					}
				}
			}
			
			if (preferredSecurityType == 0) throw new Error("Client and server cannot agree on the scurity type");
			
			rfbWriter.writeSecurityType(preferredSecurityType);
			
			rfbReader.setSecurityType(preferredSecurityType);
		}
		
		public function onSecurityVNCAuthChallenge(challenge:ByteArray):void {
			vncAuthChallenge = challenge;
			
			if (password) {
				sendPassword(password);
			} else {	
				dispatchEvent(new VNCPasswordRequieredEvent());
			}
			
			status = VNCConst.STATUS_AUTHENTICATING;
		}
		
		public function sendPassword(password:String):void {
			var key:ByteArray = new ByteArray();
			key.writeUTFBytes(password);
			var cipher:DesCipher = new DesCipher(key);
			
			cipher.encrypt(vncAuthChallenge, 0, vncAuthChallenge, 0);
			cipher.encrypt(vncAuthChallenge, 8, vncAuthChallenge, 8);
			
			rfbWriter.writeSecurityVNCAuthChallenge(vncAuthChallenge);
			
			vncAuthChallenge = null;
		}
		
		public function onSecurityOk():void {
			rfbWriter.writeClientInit(shareConnection);
		}
		
		public function onServerInit(framebufferWidth:uint,framebufferHeight:uint,serverPixelFormat:RFBPixelFormat,serverName:String):void {
			
			logger.debug(">> onServerInit()");
			
			this.serverName = serverName;
			nativeColorBigEndian = serverPixelFormat.bigEndian; 
			
			writePixelFormat();
			writeEncodings();
			
			updateRectangle = updateRectangleSettings ? updateRectangleSettings : new Rectangle(0,0,framebufferWidth,framebufferHeight);
			
			screen = new VNCScreen(framebufferHasOffset ? updateRectangle : new Rectangle(0,0,updateRectangle.width,updateRectangle.height));
			
			if (!viewOnly) addScreenEventListeners();
			
			rfbWriter.writeFramebufferUpdateRequest(false,updateRectangle);
			
			status = VNCConst.STATUS_CONNECTED;
			
			timer.stop();
			timer.removeEventListener(TimerEvent.TIMER,onConnectTimer);
			
			logger.debug("<< onServerInit()");
		}
		
		private function addScreenEventListeners():void {
			screen.addEventListener(MouseEvent.MOUSE_MOVE, onLocalMouseMove,false,0,true);
			screen.addEventListener(MouseEvent.MOUSE_DOWN, onLocalMouseLeftDown,false,0,true);
			screen.addEventListener(MouseEvent.MOUSE_UP, onLocalMouseLeftUp,false,0,true);
			screen.addEventListener(MouseEvent.MOUSE_WHEEL, onLocalMouseWheel,false,0,true);
			screen.addEventListener(MouseEvent.ROLL_OVER, onLocalMouseRollOver,false,0,true);
			screen.addEventListener(MouseEvent.ROLL_OUT, onLocalMouseRollOut,false,0,true);
			screen.addEventListener(RightMouseEvent.RIGHT_MOUSE_DOWN,onLocalMouseRightDown,false,0,true);
			screen.addEventListener(RightMouseEvent.RIGHT_MOUSE_UP,onLocalMouseRightUp,false,0,true);
			
			screen.textInput.addEventListener(KeyboardEvent.KEY_UP, onLocalKeyboardEvent,false,0,true);
			screen.textInput.addEventListener(KeyboardEvent.KEY_DOWN, onLocalKeyboardEvent,false,0,true);
			screen.textInput.addEventListener(TextEvent.TEXT_INPUT, onTextInput,false,0,true);
			screen.textInput.addEventListener(FocusEvent.KEY_FOCUS_CHANGE, onFocusLost,false,0,true);
		}
		
		private function removeScreenEventListeners():void {
			if (!screen) return;
			screen.removeEventListener(MouseEvent.MOUSE_MOVE, onLocalMouseMove,false);
			screen.removeEventListener(MouseEvent.MOUSE_DOWN, onLocalMouseLeftDown,false);
			screen.removeEventListener(MouseEvent.MOUSE_UP, onLocalMouseLeftUp,false);
			screen.removeEventListener(MouseEvent.MOUSE_WHEEL, onLocalMouseWheel,false);
			screen.removeEventListener(MouseEvent.ROLL_OVER, onLocalMouseRollOver,false);
			screen.removeEventListener(MouseEvent.ROLL_OUT, onLocalMouseRollOut,false);
			screen.removeEventListener(RightMouseEvent.RIGHT_MOUSE_DOWN,onLocalMouseRightDown,false);
			screen.removeEventListener(RightMouseEvent.RIGHT_MOUSE_UP,onLocalMouseRightUp,false);
			
			screen.textInput.removeEventListener(KeyboardEvent.KEY_UP, onLocalKeyboardEvent,false);
			screen.textInput.removeEventListener(KeyboardEvent.KEY_DOWN, onLocalKeyboardEvent,false);
			screen.textInput.removeEventListener(TextEvent.TEXT_INPUT, onTextInput,false);
			screen.textInput.removeEventListener(FocusEvent.KEY_FOCUS_CHANGE, onFocusLost,false);
		}
		
		private function onColorDepthChange(event:PropertyChangeEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			pixelFormatChangePending = true;
		}
		
		private function onEncodingChange(event:PropertyChangeEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			writeEncodings();
		}
		
		private function onJpegCompressionChange(event:PropertyChangeEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (encoding == VNCConst.ENCODING_TIGHT) writeEncodings();
		}
		
		private function onViewOnlyChange(event:PropertyChangeEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (event.oldValue == event.newValue) return;
			
			if (event.oldValue) {
				addScreenEventListeners();
			} else {
				removeScreenEventListeners();
			}
		}
		
		private function writePixelFormat():void {
			var pixelFormat:RFBPixelFormat = nativeColorBigEndian ? pixelFormats[colorDepth] : pixelFormatsLowEndian[colorDepth];
			
			rfbWriter.writeSetPixelFormat(pixelFormat);
			rfbReader.setPixelFormat(pixelFormat);
		}
		
		private function writeEncodings():void {
			
			var encodings:Array = [
				encoding,
				VNCConst.ENCODING_RAW,
				VNCConst.ENCODING_COPYRECT,
				VNCConst.ENCODING_DESKTOPSIZE
			];
			
			if (useRemoteCursor) {
				encodings.push(VNCConst.ENCODING_CURSOR);
				encodings.push(VNCConst.ENCODING_XCURSOR);
				encodings.push(VNCConst.ENCODING_CURSOR_POS);
			}
			
			if (encoding == VNCConst.ENCODING_TIGHT) {
				encodings.push(VNCConst.ENCODING_TIGHT_ZLIB_LEVEL + 9);
				if (jpegCompression != -1) encodings.push(VNCConst.ENCODING_TIGHT_JPEG_QUALITY + jpegCompression);
			}
			
			rfbWriter.writeSetEncodings(encodings);
		}
		
		private var mouseButtonMask:int = 0;
		
		public function onLocalMouseRollOver(event:MouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (!viewOnly) {
				if (useRemoteCursor) Mouse.hide();
				disableRemoteMouseEvents = true;
				captureKeyEvents = true;
				screen.stage.focus = screen.textInput;
			}
		}
		
		public function onLocalMouseRollOut(event:MouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (!viewOnly) {
				if (useRemoteCursor) Mouse.show();
				captureKeyEvents = false;
				
				// wait 500ms before activating remote cursor events to avoid cursor jittering
				var timer:Timer = new Timer(500,1);
				timer.addEventListener(TimerEvent.TIMER_COMPLETE,reactivateRemoteMouseEvent);
				timer.start();
			}
		}
		
		private function reactivateRemoteMouseEvent(event:TimerEvent):void {
			if (!captureKeyEvents) {
				disableRemoteMouseEvents = false;
			}
		}
		
		public function onLocalMouseMove(event:MouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
			screen.moveCursorTo(event.localX,event.localY);
		}
		
		public function onLocalMouseLeftDown(event:MouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			mouseButtonMask |= VNCConst.MASK_MOUSE_BUTTON_LEFT;
			rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
		}
		
		public function onLocalMouseLeftUp(event:MouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			mouseButtonMask = mouseButtonMask & (0xFF - VNCConst.MASK_MOUSE_BUTTON_LEFT);
			rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
		}
		
		public function onLocalMouseRightDown(event:RightMouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			mouseButtonMask |= VNCConst.MASK_MOUSE_BUTTON_RIGHT;
			rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
		}
		
		public function onLocalMouseRightUp(event:RightMouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			mouseButtonMask = mouseButtonMask & (0xFF - VNCConst.MASK_MOUSE_BUTTON_RIGHT);
			rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
		}
		
		public function onLocalMouseWheel(event:MouseEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			var delta:int = event.delta;
			
			while (delta > 0) {
				rfbWriter.writePointerEvent(mouseButtonMask | VNCConst.MASK_MOUSE_WHEEL_UP,new Point(event.localX,event.localY));
				rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
				delta--;
			}
			
			while (delta < 0) {
				rfbWriter.writePointerEvent(mouseButtonMask | VNCConst.MASK_MOUSE_WHEEL_DOWN,new Point(event.localX,event.localY));
				rfbWriter.writePointerEvent(mouseButtonMask,new Point(event.localX,event.localY));
				delta++
			}
		}
		
		public function onUpdateFramebufferBegin():void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			screen.lockImage();
		}
		
		public function onUpdateFramebufferEnd():void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			screen.unlockImage();
			
			if (pixelFormatChangePending) {
				writePixelFormat();
				rfbWriter.writeFramebufferUpdateRequest(false,updateRectangle);
				pixelFormatChangePending = false;
			} else {
				rfbWriter.writeFramebufferUpdateRequest(true,updateRectangle);	
			}
		}
		
		public function onServerBell():void {
			// TODO: emit event
		}
		
		public function onServerCutText(text:String):void {
			// TODO: emit event
		}
		
		public function onUpdateRectangle(rectangle:Rectangle, pixels:ByteArray):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			//if (framebufferHasOffset) rectangle.offset(-updateRectangle.x,-updateRectangle.y);
			
			screen.updateRectangle(rectangle,pixels);
		}
		
		public function onUpdateRectangleBitmapData(point:Point, bitmapData:BitmapData):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			//if (framebufferHasOffset) point.offset(-updateRectangle.x,-updateRectangle.y);
			
			screen.updateRectangleBitmapData(point,bitmapData);
		}
		
		public function onUpdateFillRectangle(rectangle:Rectangle, color:uint):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			//if (framebufferHasOffset) rectangle.offset(-updateRectangle.x,-updateRectangle.y);
			
			screen.fillRectangle(rectangle,color);
		}
		
		public function onCopyRectangle(rectangle:Rectangle, source:Point):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			//if (framebufferHasOffset) {
			//	rectangle.offset(-updateRectangle.x,-updateRectangle.y);
			//	source.offset(-updateRectangle.x,-updateRectangle.y);
			//}
			
			//if (framebufferHasOffset) 
			
			screen.copyRectangle(rectangle,source);
		}
		
		public function onChangeCursorPos(position:Point):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (!disableRemoteMouseEvents) {
				screen.moveCursorTo(position.x,position.y);
				dispatchEvent(new VNCRemoteCursorEvent(position));
			}
		}
		
		public function onChangeCursorShape(cursorShape:BitmapData, hotSpot:Point):void {
			screen.changeCursorShape(cursorShape, hotSpot);
		}
		
		public function onChangeDesktopSize(width:int,height:int):void {
			screen.resize(width,height);
		}
		
		private var captureKeyEvents:Boolean = false;
		private var shiftKeyDown:Boolean = false;
		private var crtKeyDown:Boolean = false;
		
		private function onFocusLost(event:FocusEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (captureKeyEvents) {
				event.preventDefault();
				screen.stage.focus = screen.textInput;
			}
		}
		
		public function sendCTRLALTDEL():void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			rfbWriter.writeKeyEvent(true,65507,false); //CTRL
			rfbWriter.writeKeyEvent(true,65513,false); //ALT
			rfbWriter.writeKeyEvent(true,65535,true); //DEL
			rfbWriter.writeKeyEvent(false,65507,false); //CTRL
			rfbWriter.writeKeyEvent(false,65513,false); //ALT
			rfbWriter.writeKeyEvent(false,65535,true); //DEL
		}
		
		private var expectKeyInput:Boolean = false;
		
		private function onLocalKeyboardEvent(event:KeyboardEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			if(event.ctrlKey){return;} // just disable ctrl/command keys
			
			if (captureKeyEvents) {
				
				var keysym:uint;
				logger.info(">> onLocalKeyboardEvent()");
				
				logger.info("event.type "+event.type);
				logger.info("event.keyCode "+event.keyCode);
				logger.info("event.altKey "+event.altKey);
				logger.info("event.charCode "+event.charCode);
				logger.info("event.ctrlKey "+event.ctrlKey);
				logger.info("event.keyLocation "+event.keyLocation);
				logger.info("event.shiftKey "+event.shiftKey);
				logger.info("expectKeyInput "+expectKeyInput);
				
				event.stopImmediatePropagation();
				
				switch ( event.keyCode ) {
					case Keyboard.BACKSPACE : keysym = 0xFF08; break;
					case Keyboard.TAB       : keysym = 0xFF09; break;
					case Keyboard.ENTER     : keysym = 0xFF0D; break;
					case Keyboard.ESCAPE    : keysym = 0xFF1B; break;
					case Keyboard.INSERT    : keysym = 0xFF63; break;
					case Keyboard.DELETE    : keysym = 0xFFFF; break;
					case Keyboard.HOME      : keysym = 0xFF50; break;
					case Keyboard.END       : keysym = 0xFF57; break;
					case Keyboard.PAGE_UP   : keysym = 0xFF55; break;
					case Keyboard.PAGE_DOWN : keysym = 0xFF56; break;
					case Keyboard.LEFT   	: keysym = 0xFF51; break;
					case Keyboard.UP   		: keysym = 0xFF52; break;
					case Keyboard.RIGHT   	: keysym = 0xFF53; break;
					case Keyboard.DOWN   	: keysym = 0xFF54; break;
					case Keyboard.F1   		: keysym = 0xFFBE; break;
					case Keyboard.F2   		: keysym = 0xFFBF; break;
					case Keyboard.F3   		: keysym = 0xFFC0; break;
					case Keyboard.F4   		: keysym = 0xFFC1; break;
					case Keyboard.F5   		: keysym = 0xFFC2; break;
					case Keyboard.F6   		: keysym = 0xFFC3; break;
					case Keyboard.F7   		: keysym = 0xFFC4; break;
					case Keyboard.F8   		: keysym = 0xFFC5; break;
					case Keyboard.F9   		: keysym = 0xFFC6; break;
					case Keyboard.F10  		: keysym = 0xFFC7; break;
					case Keyboard.F11  		: keysym = 0xFFC8; break;
					case Keyboard.F12  		: keysym = 0xFFC9; break;
					case Keyboard.SHIFT 	: 
						keysym = 0xFFE1; 
						shiftKeyDown = event.type == flash.events.KeyboardEvent.KEY_DOWN;
						break;
					case Keyboard.CONTROL	: keysym = 0xFFE3; break;
					default: {
						if (event.type == flash.events.KeyboardEvent.KEY_DOWN && event.ctrlKey) {
							expectKeyInput = true;
							return;
						}
						if (event.type == flash.events.KeyboardEvent.KEY_UP && expectKeyInput) {
							expectKeyInput = false;
							rfbWriter.writeKeyEvent(true,event.charCode);
							rfbWriter.writeKeyEvent(false,event.charCode);
							return;
						}
					}
				}
				
				//logger.info("keysym "+keysym);
				
				rfbWriter.writeKeyEvent(event.type == flash.events.KeyboardEvent.KEY_DOWN,keysym);
				
				//logger.info("<< onLocalKeyboardEvent()");
			}
		}

		private function onTextInput(event:TextEvent):void {
			if (status != VNCConst.STATUS_CONNECTED) return;
			
			if (captureKeyEvents) {
				
				logger.info(">> onTextInput()");
				logger.info("Shift Key Down? " + shiftKeyDown);

				expectKeyInput = false;
				
				var input:String = event.text;

				logger.info("event.text " + input);

				var useShift:Boolean; 
				var cc:uint;
                // :?<>"{}+_)(*&^%$#@!~
                var needsShift:Array = [];
				var chars:String = ":?<>\"{}+_)(*&^%$#@!~";
				var i:int = 0;
				
				for (i = 0; i < chars.length; i++) {
					needsShift.push(chars.charCodeAt(i));
				}
				
				var waitTime:int = 0;
				for (i=0; i<input.length ;i++) {
					cc=input.charCodeAt(i);
					useShift = !shiftKeyDown && needsShift.indexOf(cc) >= 0;
					if(useShift){
						 logger.info("Using shift for char " + cc);
						 setTimeout(rfbWriter.writeKeyEvent, waitTime += 50, true, 0xFFE1, true);
					}
					setTimeout(rfbWriter.writeKeyEvent, waitTime += 20, true, cc, false);
					setTimeout(rfbWriter.writeKeyEvent, waitTime += 20, false, cc, true);
					if(useShift){
						setTimeout(rfbWriter.writeKeyEvent, waitTime += 50, false, 0xFFE1, true);
					}
					waitTime += 100;
				}
				
				screen.textInput.text ='';
				
				logger.info("<< onTextInput()");
			}
		}
		
		private function onError(specificMessage:String,e:Error):void {
			logger.error(specificMessage+(e ? ": "+e.getStackTrace() : ""));
			dispatchEvent(new VNCErrorEvent(specificMessage+(e ? ": "+e.message : "")));
			disconnect();
			
			if (ExternalInterface.available) { 
				try { 
					ExternalInterface.call("FlashlightVncOnError", specificMessage, e); 
				} catch (e:Error) {
					logger.error(specificMessage+(e ? ": "+e.getStackTrace() : ""));
				}
			} else {
				logger.info("External interface is not available.");	
			}
		}
		
		private function onReconnect():void {
			if (ExternalInterface.available) { 
				try { 
					ExternalInterface.call("FlashlightOnReconnect"); 
				} catch (e:Error) {
					logger.error(e ? ": "+e.getStackTrace() : "");
				}
			} else {
				logger.info("External interface is not available.");	
			}
		}
		
		private function onSocketConnect(event:Event):void {
			rfbReader = new RFBReader(socket, this);
			
			status = VNCConst.STATUS_WAITING_SERVER;
			
			if(testingStatus === VNCConst.TEST_CONNECTION_SUCCESSFUL){
				testingStatus = VNCConst.TEST_CONNECTION_DISABLED;
				onReconnect();
			}
			//Application.application.addEventListener(Event.ENTER_FRAME, onEnterNewFrame,false,0,true);
		}
		
		private function onSocketData(event:ProgressEvent):void {
			onEnterNewFrame(event);
		}
		
		private function onEnterNewFrame(event:Event):void {
			try {
				rfbReader.readData();
			} catch (e:RFBReaderError) {
				onError("Error when reading RFB "+e.reader,e.cause);	
			} catch (e:Error) {
				onError("An unexpected error occured",e);	
			}
		}
		
		private function onSocketClose(event:Event):void {
			if (status !== VNCConst.STATUS_NOT_CONNECTED) 
			{
				disconnect();
				if(reConnect)
				{
					testConnection();
				}
				else
				{
					onError("Connection lost",null); 
				}
			}
		}
		
		private function testConnection():void{
			if(testingStatus !== VNCConst.TEST_CONNECTION_CHECKING){ //Avoid multiple error listeners attempting to reconnect
				testVNCConnection();
				timer.addEventListener(TimerEvent.TIMER,onConnectTimer);
				timer.start();	
			}
		}
		
		private function onConnectTimer(event:TimerEvent):void {
			if(testingStatus === VNCConst.TEST_CONNECTION_CHECKING) //If test connection is successful, stop the timer
				testVNCConnection();
			else{
				timer.stop();
				timer.reset();
			}
		}
		
		private function testVNCConnection():void {
			testingStatus = VNCConst.TEST_CONNECTION_CHECKING;
			
			Security.loadPolicyFile("xmlsocket://"+host+":"+port);
			var s:Socket = new Socket();
			s.addEventListener(IOErrorEvent.IO_ERROR, onVNCIOError);
			s.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityPortKo);
			s.addEventListener(Event.CONNECT, onVNCConnectionOk);
			s.connect(host,port);
		}
		
		private function onVNCIOError(event:IOErrorEvent):void {
			status = VNCConst.STATUS_RE_CONNECTING;
		}
		
		private function onSecurityPortKo(event:SecurityErrorEvent):void {
			status = VNCConst.STATUS_RE_CONNECTING;
		}
		private function onVNCConnectionOk(event:Event):void {
			testingStatus = VNCConst.TEST_CONNECTION_SUCCESSFUL;
			connect();
		}
		public function disconnect():void {
			logger.debug(">> disconnect()");
			
			//Application.application.removeEventListener(Event.ENTER_FRAME, onEnterNewFrame);
			
			// clean everything
			if (socket) {
				if (socket.connected) socket.close();
				socket = null;
			}
			removeScreenEventListeners();
			screen = null;
			rfbReader = null;		    
			vncAuthChallenge = null;
			serverName = undefined;
			pixelFormatChangePending = false;
			Mouse.show();
			captureKeyEvents = false;
			
			status = VNCConst.STATUS_NOT_CONNECTED;
			
			logger.debug("<< disconnect()");
		}
		
		private function onSocketError(event:IOErrorEvent):void {
			onError("An IO error occured: " + event.type+", "+event.text,null);
			if(reConnect)				testConnection();
		}
		
		private function onSocketSecurityError(event:SecurityErrorEvent):void {
			onError("An security error occured ("+event.text+").\n" + 
				"Check your policy-policy server configuration or disable security for this domain.",null);
			if(reConnect)				testConnection();
		}
		
	}
}
