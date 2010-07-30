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

package com.flashlight.pixelformats {
	import flash.display.BitmapData;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Point;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.IDataInput;
	
	public class RFBPixelFormat32bppLittleEndian extends RFBPixelFormat {
				
		public function RFBPixelFormat32bppLittleEndian() {
			super({
				bitsPerPixel: 32,
			    depth: 24,
			    bigEndian: false,
			    trueColour: true,
			    maxRed: 255,
			    maxGreen: 255,
			    maxBlue: 255,
			    shiftRed: 16,
			    shiftGreen: 8,
			    shiftBlue: 0
			});
		}
		
		override public function getPixelDataSize():uint {
			return 4;
		}
		
		override public function getPixelsDataSize(width:uint,height:uint):uint {
			return height*width*4;
		}
		
		override public function readPixels(width:uint,height:uint,inputStream:IDataInput):ByteArray {
			var pixels:ByteArray = new ByteArray();
			inputStream.readBytes(pixels, 0, height*width*4)
			pixels.endian = Endian.LITTLE_ENDIAN;
			return pixels;
		}
		
		override public function readPixel(inputStream:IDataInput):uint {
			inputStream.endian = Endian.LITTLE_ENDIAN;
			var result:uint = inputStream.readUnsignedInt();
			inputStream.endian = Endian.BIG_ENDIAN;
			return result;
		}
	}
}