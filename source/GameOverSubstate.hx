package;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;

class GameOverSubstate extends MusicBeatSubstate
{
	var bf:Boyfriend;
	var camFollow:FlxPoint;
	var camFollowPos:FlxObject;
	var updateCamera:Bool = false;

	var stageSuffix:String = "";

	var lePlayState:PlayState;

	public static var characterName:String = 'bf';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var camZoom:Float = 0.9;

	var deathText:FlxText;
	var deathTextEng:FlxText;

	var deathTextList:Array<String> = ['아하하하하!!! \n결정... 결정... 사형으로 결정!', '역시 내 생각대로 당연한결과로구만!', '어이 개발린거냐구~ \n다 끝난거냐구~ \n완전 허접하다구~',
	'아하하 아하하x2 우엑', '어이가 없군, 겨우 이정도의 실험체였다니', '우리는 언제나 완벽하지... \n아! 물론 넌 아니겠지만 말이야!', '많은 사람들이 어떤 화장실을 가냐고 물어보던데... \n그딴걸 대체 왜 궁금해하는거야?', 
	'해부.. 추출... 사형!', '잘가라 나의 실험체여!', '난 너희 히어로들이 \n너무나 싫단 말이야. 왜냐고? \n가당치도 않은 실력으로 나를 이기려고 하니까!', '네놈들 때문에 로봇을 만들 시간이 없잖아!'];

	var deathTextListEng:Array<String> = ['Ahahahaha! \nI demand you... a death sentence!', 'This is just what I expected.', 'Is this all you got~? \nIs it over? \nWhat a pity!', 'Ahaha, Ahahaha x2, Bleh',
	"I can't believe that you can do only this much, \nI even feel shame to call you my subject.", 'We are always perfect... \nAh! except you, of course!', 'People were keep asking me which toliet I went to... \nwhy the heck are they wondering that?', 
	'Dissection... Extraction... Execution!', 'Farewell, my dear subject!', 'I hate heros so much, \nwhy do they keep try to beat me with their poor performance?', "You're waisting my time to make new robots!"];

	public static function resetVariables() {
		characterName = 'bf';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		camZoom = 0.9;
	}

	public function new(x:Float, y:Float, camX:Float, camY:Float, state:PlayState)
	{
		lePlayState = state;
		state.setOnLuas('inGameOver', true);
		super();

		Conductor.songPosition = 0;

		bf = new Boyfriend(x, y, characterName);
		add(bf);

		//deathTextList = ['coolswag'];

		deathText = new FlxText(bf.x - 500, bf.y + 450, Std.int(FlxG.width * 0.6), "", 72);
		deathText.setFormat(Paths.font('strongarmy.ttf'), 72, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		deathText.antialiasing = true;
		deathText.borderQuality = 1;
		deathText.borderSize = 12;
		add(deathText);

		deathTextEng = new FlxText(bf.x + 300 , bf.y + 450, Std.int(FlxG.width * 0.6), "", 72);
		deathTextEng.setFormat(Paths.font('strongarmy.ttf'), 72, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		deathTextEng.antialiasing = true;
		deathTextEng.borderQuality = 1;
		deathTextEng.borderSize = 12;
		add(deathTextEng);

		camFollow = new FlxPoint(bf.getGraphicMidpoint().x, bf.getGraphicMidpoint().y);

		FlxG.sound.play(Paths.sound(deathSoundName));
		Conductor.changeBPM(100);
		// FlxG.camera.followLerp = 1;
		// FlxG.camera.focusOn(FlxPoint.get(FlxG.width / 2, FlxG.height / 2));
		FlxG.camera.zoom = camZoom; //no more zoom bug yay
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		bf.playAnim('firstDeath');

		var exclude:Array<Int> = [];

		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.setPosition(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2));
		add(camFollowPos);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		lePlayState.callOnLuas('onUpdate', [elapsed]);
		if(updateCamera) {
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 0.6, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		}

		if (controls.ACCEPT)
		{
			endBullshit();
		}

		if (controls.BACK)
		{
			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;

			if (PlayState.isStoryMode)
				MusicBeatState.switchState(new StoryMenuState());
			else
				MusicBeatState.switchState(new FreeplayState());

			FlxG.sound.playMusic(Paths.music('introduce'));
			lePlayState.callOnLuas('onGameOverConfirm', [false]);
		}

		if (bf.animation.curAnim.name == 'firstDeath')
		{
			if(bf.animation.curAnim.curFrame == 12)
			{
				FlxG.camera.follow(camFollowPos, LOCKON, 1);
				updateCamera = true;
			}

			if (bf.animation.curAnim.finished)
			{
				coolStartDeath();
				bf.startedDeath = true;
			}
		}

		if (FlxG.sound.music.playing)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}
		lePlayState.callOnLuas('onUpdatePost', [elapsed]);
	}

	override function beatHit()
	{
		super.beatHit();

		//FlxG.log.add('beat');
	}

	var isEnding:Bool = false;

	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.playMusic(Paths.music(loopSoundName), volume);
		var randomDeathSound = FlxG.random.int(1,11);
		FlxG.sound.play(Paths.sound('death' + randomDeathSound));
		if (randomDeathSound != 4)
		{
			deathText.text = deathTextList[randomDeathSound - 1];
			deathTextEng.text = deathTextListEng[randomDeathSound - 1];
		}
	}

	function endBullshit():Void
	{
		if (!isEnding)
		{
			//remove(deathText);
			//deathText.destroy();

			deathText.text = "이 세상을 악으로부터 구원한다!";
			deathTextEng.text = "Saving world from the evil!";

			isEnding = true;
			bf.playAnim('deathConfirm', true);
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					MusicBeatState.resetState();
				});
			});
			lePlayState.callOnLuas('onGameOverConfirm', [true]);
		}
	}
}
