package;

import openfl.filters.ShaderFilter;

class RGBHandler
{
	public static var rgbSplit:ShaderFilter = new ShaderFilter(new RGBSplit());
	
	public static function setRgb(rgbOffsetX:Float, rgbOffsetY:Float):Void
	{
		rgbSplit.shader.data.rOffsetX.value = [rgbOffsetX];
		rgbSplit.shader.data.gOffsetX.value = [0.0];
		rgbSplit.shader.data.bOffsetX.value = [rgbOffsetX * -1];
		rgbSplit.shader.data.rOffsetY.value = [rgbOffsetY];
		rgbSplit.shader.data.gOffsetY.value = [0.0];
		rgbSplit.shader.data.bOffsetY.value = [rgbOffsetY * -1];
	}
}