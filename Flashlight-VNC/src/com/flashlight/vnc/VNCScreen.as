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
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.PixelSnapping;
	import flash.display.Sprite;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.utils.ByteArray;
	
	import mx.controls.Alert;
	
	public class VNCScreen extends Sprite {
		
		[@Embed(source='/assets/cursor.gif')]
		private static var DefaultCursorClass:Class;
		private static var defaultCursor:DisplayObject = new DefaultCursorClass();
		
		private var offsetX:int;
		private var offsetY:int;
		private var fixedWidth:int;
		private var fixedHeight:int;
		private var cursor:VNCCursor;
		private var screen:Bitmap;
		private var screenData:BitmapData;
		
		public var textInput:TextField;				
		
		public function VNCScreen(dimension:Rectangle) {
			super();
			
			scrollRect = dimension;
			
			fixedWidth = dimension.width;
			fixedHeight = dimension.height;
			offsetX = dimension.x;
			offsetY = dimension.y;
			screenData = new BitmapData(offsetX+fixedWidth, offsetY+fixedHeight, false, 0x00000000);
			screen = new Bitmap(screenData, PixelSnapping.AUTO, true);
			
			cursor = new VNCCursor(defaultCursor);
			
			textInput= new TextField();
			textInput.type = TextFieldType.INPUT;
			textInput.width = 0;
			
			addChild(textInput);
			addChild(screen);
			addChild(cursor);
		}
		
		public function resize(width:int, height:int):void {
			if (width == fixedWidth && height == fixedHeight) return;
			
			scrollRect = new Rectangle(offsetX,offsetY,width,height);
			
			fixedWidth = width;
			fixedHeight = height;
			screenData = new BitmapData(offsetX+fixedWidth, offsetY+fixedHeight, false, 0x00000000);
			screen.bitmapData = screenData;
		}
		
		override public function get height():Number {
			return fixedHeight;
		}
		
		override public function get width():Number {
			return fixedWidth;
		} 
		
		public function getRectangle():Rectangle {
			return screenData.rect;
		}
		
		public function lockImage():void {
			screenData.lock();
		}
		
		public function unlockImage():void {
			screenData.unlock();
		}
		
		public function updateRectangle(rectangle:Rectangle, pixels:ByteArray):void {
			screenData.setPixels(rectangle, pixels);
		}
		
		public function updateRectangleBitmapData(point:Point, bitmapData:BitmapData):void {
			screenData.copyPixels(bitmapData,bitmapData.rect,point);
		}
		
		public function fillRectangle(rectangle:Rectangle, color:uint):void {
			screenData.fillRect(rectangle,color);
		}
		
		public function copyRectangle(rectangle:Rectangle, source:Point):void {
			var src:Rectangle = new Rectangle(source.x,source.y,rectangle.width, rectangle.height);
			var pixels:ByteArray = screenData.getPixels(src);
			pixels.position = 0;
			screenData.setPixels(rectangle, pixels);
		}
		
		public function changeCursorShape(cursorShape:BitmapData, hotSpot:Point):void {
			cursor.changeShape(cursorShape, hotSpot);
		}
		
		public function moveCursorTo(x:int,y:int):void {
			cursor.moveTo(x,y);
		}
	}
}