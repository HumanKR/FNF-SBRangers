package;

import flixel.system.FlxAssets.FlxShader;

class RGBSplit extends FlxShader
{
    /*
        Thanks to GWebDev goes brrrrrrrrrr 
    */

	@:glFragmentSource('
		#pragma header

		uniform float rOffsetX;
		uniform float gOffsetX;
		uniform float bOffsetX;
		uniform float rOffsetY;
		uniform float gOffsetY;
		uniform float bOffsetY;

		void main()
		{
			vec4 col1 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(rOffsetX, rOffsetY));
			vec4 col2 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(gOffsetX, rOffsetY));
			vec4 col3 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(bOffsetX, rOffsetY));
			vec4 GO = texture2D(bitmap, openfl_TextureCoordv);
			GO.r = col1.r;
			GO.g = col2.g;
			GO.b = col3.b;

			gl_FragColor = GO;
		}')

	public function new()
	{
		super();
	}
}