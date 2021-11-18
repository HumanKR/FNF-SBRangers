package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.text.FlxTypeText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.input.FlxKeyManager;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.FlxSubState;
import haxe.Json;
import haxe.format.JsonParser;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxCamera;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import openfl.utils.Assets;

using StringTools;

typedef DialogueCharacterFile = {
	var image:String;
	var dialogue_pos:String;

	var animations:Array<DialogueAnimArray>;
	var position:Array<Float>;
	var scale:Float;
}

typedef DialogueAnimArray = {
	var anim:String;
	var loop_name:String;
	var loop_offsets:Array<Int>;
	var idle_name:String;
	var idle_offsets:Array<Int>;
}

// Gonna try to kind of make it compatible to Forever Engine,
// love u Shubs no homo :flushedh4:
typedef DialogueFile = {
	var dialogue:Array<DialogueLine>;
}

typedef DialogueLine = {
	var portrait:Null<String>;
	var expression:Null<String>;
	var text:Null<String>;
	var boxState:Null<String>;
	var speed:Null<Float>;
}

class DialogueCharacter extends FlxSprite
{
	private static var IDLE_SUFFIX:String = '-IDLE';
	public static var DEFAULT_CHARACTER:String = 'bf';
	public static var DEFAULT_SCALE:Float = 0.7;

	public var jsonFile:DialogueCharacterFile = null;
	#if (haxe >= "4.0.0")
	public var dialogueAnimations:Map<String, DialogueAnimArray> = new Map();
	#else
	public var dialogueAnimations:Map<String, DialogueAnimArray> = new Map<String, DialogueAnimArray>();
	#end

	public var startingPos:Float = 0; //For center characters, it works as the starting Y, for everything else it works as starting X
	public var isGhost:Bool = false; //For the editor
	public var curCharacter:String = 'bf';

	public function new(x:Float = 0, y:Float = 0, character:String = null)
	{
		super(x, y);

		if(character == null) character = DEFAULT_CHARACTER;
		this.curCharacter = character;

		reloadCharacterJson(character);
		frames = Paths.getSparrowAtlas('dialogue/' + jsonFile.image);
		reloadAnimations();
	}

	public function reloadCharacterJson(character:String) {
		var characterPath:String = 'images/dialogue/' + character + '.json';
		var rawJson = null;

		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}

		if(!FileSystem.exists(path)) {
			path = Paths.getPreloadPath('images/dialogue/' + DEFAULT_CHARACTER + '.json');
		}
		rawJson = File.getContent(path);

		#else
		var path:String = Paths.getPreloadPath(characterPath);
		rawJson = Assets.getText(path);
		#end
		
		jsonFile = cast Json.parse(rawJson);
	}

	public function reloadAnimations() {
		dialogueAnimations.clear();
		if(jsonFile.animations != null && jsonFile.animations.length > 0) {
			for (anim in jsonFile.animations) {
				animation.addByPrefix(anim.anim, anim.loop_name, 24, isGhost);
				animation.addByPrefix(anim.anim + IDLE_SUFFIX, anim.idle_name, 24, true);
				dialogueAnimations.set(anim.anim, anim);
			}
		}
	}

	public function playAnim(animName:String = null, playIdle:Bool = false) {
		var leAnim:String = animName;
		if(animName == null || !dialogueAnimations.exists(animName)) { //Anim is null, get a random animation
			var arrayAnims:Array<String> = [];
			for (anim in dialogueAnimations) {
				arrayAnims.push(anim.anim);
			}
			if(arrayAnims.length > 0) {
				leAnim = arrayAnims[FlxG.random.int(0, arrayAnims.length-1)];
			}
		}

		if(dialogueAnimations.exists(leAnim) &&
		(dialogueAnimations.get(leAnim).loop_name == null ||
		dialogueAnimations.get(leAnim).loop_name.length < 1 ||
		dialogueAnimations.get(leAnim).loop_name == dialogueAnimations.get(leAnim).idle_name)) {
			playIdle = true;
		}
		animation.play(playIdle ? leAnim + IDLE_SUFFIX : leAnim, false);

		if(dialogueAnimations.exists(leAnim)) {
			var anim:DialogueAnimArray = dialogueAnimations.get(leAnim);
			if(playIdle) {
				offset.set(anim.idle_offsets[0], anim.idle_offsets[1]);
				//trace('Setting idle offsets: ' + anim.idle_offsets);
			} else {
				offset.set(anim.loop_offsets[0], anim.loop_offsets[1]);
				//trace('Setting loop offsets: ' + anim.loop_offsets);
			}
		} else {
			offset.set(0, 0);
			trace('Offsets not found! Dialogue character is badly formatted, anim: ' + leAnim + ', ' + (playIdle ? 'idle anim' : 'loop anim'));
		}
	}

	public function animationIsLoop():Bool {
		if(animation.curAnim == null) return false;
		return !animation.curAnim.name.endsWith(IDLE_SUFFIX);
	}
}

// TO DO: Clean code? Maybe? idk
class DialogueBoxPsych extends FlxSpriteGroup
{
	var dialogue:Alphabet;
	var dialogueList:DialogueFile = null;

	public var finishThing:Void->Void;
	public var nextDialogueThing:Void->Void = null;
	public var skipDialogueThing:Void->Void = null;
	var bgFade:FlxSprite = null;
	var box:FlxSprite;
	var textToType:String = '';

	var arrayCharacters:Array<DialogueCharacter> = [];

	var currentText:Int = 0;
	var offsetPos:Float = -600;

	var textBoxTypes:Array<String> = ['normal', 'angry'];
	//var charPositionList:Array<String> = ['left', 'center', 'right'];


	var cutPath:String = 'waldo/cut/';
	public var curCutscene:Int = 1;
	var cutscene:FlxSprite;
	var cutsceneFront:FlxSprite;
	public var doCutscene:Int = 1;

	public static var camSans:FlxCamera;
	var defaultCamZoom:Float = 1;

	public function new(dialogueList:DialogueFile, ?song:String = null)
	{
		super();
		camSans = new FlxCamera();
		//FlxG.cameras.reset(camSans);
		//camSans.bgColor.alpha = 0;
		//FlxG.cameras.add(camSans);
		//FlxG.cameras.setDefaultDrawTarget(camSans, true);
		//FlxG.camera.zoom = 1;
		defaultCamZoom = camSans.zoom;

		if(song != null && song != '') {
			FlxG.sound.playMusic(Paths.music(song), 0);
			FlxG.sound.music.fadeIn(2, 0, 1);
		}
		
		switch (PlayState.curStage)
		{
			case 'waldoStage':
				bgFade = new FlxSprite(0,0);
				add(bgFade);
				FlxG.sound.playMusic(Paths.music('drwaldo_theme'), 0.8);

				cutscene = new FlxSprite(0, 0).loadGraphic(Paths.image(cutPath + doCutscene));
			case 'waldoSecondStage':
				bgFade = new FlxSprite(0,0);
				add(bgFade);
				FlxG.sound.playMusic(Paths.music('drwaldo_theme'), 0.8);

				doCutscene = 4;
			case 'waldoFinalStage':
				bgFade = new FlxSprite(0,0);
				add(bgFade);
				FlxG.sound.playMusic(Paths.music('megagu_theme'), 0.8);
				//FlxG.sound.load(Paths.music('megagu_theme'));
				FlxG.sound.music.play(false, 80000);
				doCutscene = 8;
			default:
				bgFade = new FlxSprite(-500, -500).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.WHITE);
				bgFade.scrollFactor.set();
				bgFade.visible = true;
				bgFade.alpha = 0;
				add(bgFade);
		}

		if (PlayState.curStage == 'waldoStage' || PlayState.curStage == 'waldoSecondStage' || PlayState.curStage == 'waldoFinalStage')
		{
			cutscene = new FlxSprite(0, 0).loadGraphic(Paths.image(cutPath + doCutscene));
			cutscene.setGraphicSize(1280, 720); 
			cutscene.screenCenter(X);
			cutscene.screenCenter(Y);
			cutscene.antialiasing = true;
			add(cutscene);
			//cutscene.cameras = [camSans];
		}

		this.dialogueList = dialogueList;
		if(PlayState.curStage != 'waldoStage' && PlayState.curStage != 'waldoSecondStage' && PlayState.curStage != 'waldoFinalStage')
			spawnCharacters();

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.scrollFactor.set();
		box.antialiasing = ClientPrefs.globalAntialiasing;
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('normalOpen', 'Speech Bubble Normal Open', 24, false);
		box.animation.addByPrefix('angry', 'AHH speech bubble', 24);
		box.animation.addByPrefix('angryOpen', 'speech bubble loud open', 24, false);
		box.animation.addByPrefix('center-normal', 'speech bubble middle', 24);
		box.animation.addByPrefix('center-normalOpen', 'Speech Bubble Middle Open', 24, false);
		box.animation.addByPrefix('center-angry', 'AHH Speech Bubble middle', 24);
		box.animation.addByPrefix('center-angryOpen', 'speech bubble Middle loud open', 24, false);
		box.animation.play('normal', true);
		box.visible = false;
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();

		if (PlayState.curStage == 'waldoStage' || PlayState.curStage == 'waldoSecondStage' || PlayState.curStage == 'waldoFinalStage')
			box.alpha = 0.5;

		add(box);

		//box.cameras = [camSans];

		if(PlayState.curStage == 'waldoStage' || PlayState.curStage == 'waldoSecondStage' || PlayState.curStage == 'waldoFinalStage')
			spawnCharacters();

		startNextDialog();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	var dialogueStarted:Bool = false;
	var dialogueEnded:Bool = false;

	public static var LEFT_CHAR_X:Float = -60;
	public static var RIGHT_CHAR_X:Float = -100;
	public static var DEFAULT_CHAR_Y:Float = 60;

	function spawnCharacters() {
		#if (haxe >= "4.0.0")
		var charsMap:Map<String, Bool> = new Map();
		#else
		var charsMap:Map<String, Bool> = new Map<String, Bool>();
		#end
		for (i in 0...dialogueList.dialogue.length) {
			if(dialogueList.dialogue[i] != null) {
				var charToAdd:String = dialogueList.dialogue[i].portrait;
				if(!charsMap.exists(charToAdd) || !charsMap.get(charToAdd)) {
					charsMap.set(charToAdd, true);
				}
			}
		}

		for (individualChar in charsMap.keys()) {
			var x:Float = LEFT_CHAR_X;
			var y:Float = DEFAULT_CHAR_Y;
			var char:DialogueCharacter = new DialogueCharacter(x + offsetPos, y, individualChar);

			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * char.jsonFile.scale));
			char.updateHitbox();
			char.antialiasing = ClientPrefs.globalAntialiasing;
			char.scrollFactor.set();
			char.alpha = 0.00001;
			add(char);

			//char.cameras = [camSans];

			var saveY:Bool = false;
			switch(char.jsonFile.dialogue_pos) {
				case 'center':
					char.x = FlxG.width / 2;
					char.x -= char.width / 2;
					y = char.y;
					char.y = FlxG.height + 50;
					saveY = true;
				case 'right':
					x = FlxG.width - char.width + RIGHT_CHAR_X;
					char.x = x - offsetPos;
			}
			x += char.jsonFile.position[0];
			y += char.jsonFile.position[1];
			char.x += char.jsonFile.position[0];
			char.y += char.jsonFile.position[1];
			char.startingPos = (saveY ? y : x);
			arrayCharacters.push(char);
		}
	}

	public static var DEFAULT_TEXT_X = 90;
	public static var DEFAULT_TEXT_Y = 430;
	var scrollSpeed = 4500;
	var daText:Alphabet = null;
	var ignoreThisFrame:Bool = true; //First frame is reserved for loading dialogue images

	var cutBool:Bool = false;

	override function update(elapsed:Float)
	{
		if(ignoreThisFrame) {
			ignoreThisFrame = false;
			super.update(elapsed);
			return;
		}

		if(!dialogueEnded) {
			bgFade.alpha += 0.5 * elapsed;
			//cutscene.alpha += 1 * elapsed;  //it seems i don't need it
			if(bgFade.alpha > 0.5) bgFade.alpha = 0.5;
			//if(cutscene.alpha > 1) cutscene.alpha = 1;

			if(PlayerSettings.player1.controls.ACCEPT && !cutBool) {
				if(!daText.finishedText) {
					if(daText != null) {
						daText.killTheTimer();
						daText.kill();
						remove(daText);
						daText.destroy();
					}
					//if (curCutscene != 12)	{
						daText = new Alphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, textToType, false, true, 0.0, 0.7);
						add(daText);
						//daText.cameras = [camSans];
					//}

					if(skipDialogueThing != null) {
						skipDialogueThing();
					}
				} else if(currentText >= dialogueList.dialogue.length) {
					dialogueEnded = true;
					for (i in 0...textBoxTypes.length) {
						var checkArray:Array<String> = ['', 'center-'];
						var animName:String = box.animation.curAnim.name;
						for (j in 0...checkArray.length) {
							if(animName == checkArray[j] + textBoxTypes[i] || animName == checkArray[j] + textBoxTypes[i] + 'Open') {
								box.animation.play(checkArray[j] + textBoxTypes[i] + 'Open', true);
							}
						}
					}

					box.animation.curAnim.curFrame = box.animation.curAnim.frames.length - 1;
					box.animation.curAnim.reverse();
					daText.kill();
					remove(daText);
					daText.destroy();
					daText = null;
					updateBoxOffsets(box);
					FlxG.sound.music.fadeOut(1, 0);
				} else {
					curCutscene++;
					trace('curCut: ' + curCutscene);

					switch (PlayState.curStage) //noooo here we go agian
					{
						case 'waldoStage':
							switch (curCutscene)
							{
								case 5 | 7 | 8:
									doCutscene++;
								case 6:
									doCutscene--;
							
							}
						case 'waldoSecondStage':
							switch (curCutscene)
							{
								case 6 | 7:
									doCutscene++;
								case 4:
									doCutscene++;
									camera.shake(0.03, 0.3);	
									FlxG.sound.music.stop();
									FlxG.sound.playMusic(Paths.music('megagu_theme'), 0.8);
							}
						case 'waldoFinalStage':
							switch (curCutscene)
							{
								case 6 | 11 | 13 | 14 | 16:
									doCutscene++;
								case 4:
									doCutscene++;

									FlxG.sound.play(Paths.sound('shoot'));
									camera.shake(0.03, 0.3);	
									FlxG.sound.music.stop();
								case 12: //12번 컷신 구현 "what... what the 뜨기 전"
								cutBool = true; //아니 이게 대체 무슨 코드야 돌겠네 진짜;;;;;;;

								doCutscene++;

								daText.killTheTimer();
								daText.kill();
								remove(daText);
								daText.destroy();

								daText = new Alphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, textToType, false, true, 0.0, 0.7);
								add(daText);
								startNextDialog();

								trace('doCut: ' + doCutscene);
								cutscene.loadGraphic(Paths.image(cutPath + doCutscene));

								cutsceneFront = new FlxSprite(0, 0).loadGraphic(Paths.image(cutPath + doCutscene));
								cutsceneFront.setGraphicSize(1280, 720); 
								cutsceneFront.screenCenter(X);
								cutsceneFront.screenCenter(Y);
								cutsceneFront.antialiasing = true;
								add(cutsceneFront);
								cutsceneFront.visible = false;

								var whiteThings = new FlxSprite(-500, -500).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.WHITE); //i'm not have a time to learn tween fade
								whiteThings.scrollFactor.set(); //today is damn D-day brrrrrrr
								whiteThings.visible = true;
								whiteThings.alpha = 0;
								add(whiteThings);

								FlxG.sound.play(Paths.sound('impact'));

								new FlxTimer().start(0.5, function(tmr:FlxTimer)
								{
									FlxTween.tween(whiteThings, {alpha: 1}, 1);
									FlxTween.tween(camera, {zoom: defaultCamZoom + 1}, 1,
									{
										ease: FlxEase.quartIn,
										onComplete: function(twn:FlxTween)
										{
											doCutscene++;
											trace('doCut: ' + doCutscene);
											//cutscene.loadGraphic(Paths.image(cutPath + doCutscene));

											cutsceneFront.loadGraphic(Paths.image(cutPath + doCutscene));//i want to make this without visible code things damn
											cutsceneFront.visible = true;

											daText.killTheTimer();
											daText.kill();
											remove(daText);
											daText.destroy();
											box.visible = false;

											FlxTween.tween(whiteThings, {alpha: 0}, 1);
											FlxTween.tween(camera, {zoom: defaultCamZoom}, 1,
											{
												ease: FlxEase.quartOut,
												onComplete: function(twn:FlxTween)
												{
													
													remove(cutsceneFront);
													cutsceneFront.destroy();

													daText = new Alphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, textToType, false, true, 0.0, 0.7);
													add(daText);
													startNextDialog();
													box.visible = true;

													doCutscene++;
													trace('doCut: ' + doCutscene);
													cutscene.loadGraphic(Paths.image(cutPath + doCutscene));

													FlxG.sound.playMusic(Paths.music('azi_missile_theme'), 0.8);

													camera.shake(0.1, 0.5, null, true);	
													cutBool = false;
													//camera.zoom = defaultCamZoom;
												}
											});
										}
									});				
								});
								case 17:
									doCutscene++;
									camera.shake(0.05, 0.3, null, true);
							}
						}
						if (PlayState.curStage == 'waldoStage' || PlayState.curStage == 'waldoSecondStage' || PlayState.curStage == 'waldoFinalStage')
						{
							if(!cutBool)
							{
								trace('doCut: ' + doCutscene);
								cutscene.loadGraphic(Paths.image(cutPath + doCutscene));
							}
						}
					if(!cutBool)
						startNextDialog();
				}
				FlxG.sound.play(Paths.sound('dialogueClose'));
			} else if(daText.finishedText) {
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if(char != null && char.animation.curAnim != null && char.animationIsLoop() && char.animation.finished) {
					char.playAnim(char.animation.curAnim.name, true);
				}
			} else {
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if(char != null && char.animation.curAnim != null && char.animation.finished) {
					char.animation.curAnim.restart();
				}
			}

			if(box.animation.curAnim.finished) {
				for (i in 0...textBoxTypes.length) {
					var checkArray:Array<String> = ['', 'center-'];
					var animName:String = box.animation.curAnim.name;
					for (j in 0...checkArray.length) {
						if(animName == checkArray[j] + textBoxTypes[i] || animName == checkArray[j] + textBoxTypes[i] + 'Open') {
							box.animation.play(checkArray[j] + textBoxTypes[i], true);
						}
					}
				}
				updateBoxOffsets(box);
			}

			if(lastCharacter != -1 && arrayCharacters.length > 0) {
				for (i in 0...arrayCharacters.length) {
					var char = arrayCharacters[i];
					if(char != null) {
						if(i != lastCharacter) {
							switch(char.jsonFile.dialogue_pos) {
								case 'left':
									char.x -= scrollSpeed * elapsed;
									if(char.x < char.startingPos + offsetPos) char.x = char.startingPos + offsetPos;
								case 'center':
									char.y += scrollSpeed * elapsed;
									if(char.y > char.startingPos + FlxG.height) char.y = char.startingPos + FlxG.height;
								case 'right':
									char.x += scrollSpeed * elapsed;
									if(char.x > char.startingPos - offsetPos) char.x = char.startingPos - offsetPos;
							}
							char.alpha -= 3 * elapsed;
							if(char.alpha < 0.00001) char.alpha = 0.00001;
						} else {
							switch(char.jsonFile.dialogue_pos) {
								case 'left':
									char.x += scrollSpeed * elapsed;
									if(char.x > char.startingPos) char.x = char.startingPos;
								case 'center':
									char.y -= scrollSpeed * elapsed;
									if(char.y < char.startingPos) char.y = char.startingPos;
								case 'right':
									char.x -= scrollSpeed * elapsed;
									if(char.x < char.startingPos) char.x = char.startingPos;
							}
							char.alpha += 3 * elapsed;
							if(char.alpha > 1) char.alpha = 1;
						}
					}
				}
			}
		} else { //Dialogue ending
			if(box != null && box.animation.curAnim.curFrame <= 0) {
				box.kill();
				remove(box);
				box.destroy();
				box = null;
			}

			if(bgFade != null) {
				bgFade.alpha -= 0.5 * elapsed;
				if(bgFade.alpha <= 0) {
					bgFade.kill();
					remove(bgFade);
					bgFade.destroy();
					bgFade = null;
				}
			}

			for (i in 0...arrayCharacters.length) {
				var leChar:DialogueCharacter = arrayCharacters[i];
				if(leChar != null) {
					switch(arrayCharacters[i].jsonFile.dialogue_pos) {
						case 'left':
							leChar.x -= scrollSpeed * elapsed;
						case 'center':
							leChar.y += scrollSpeed * elapsed;
						case 'right':
							leChar.x += scrollSpeed * elapsed;
					}
					leChar.alpha -= elapsed * 10;
				}
			}

			if(box == null && bgFade == null) {
				for (i in 0...arrayCharacters.length) {
					var leChar:DialogueCharacter = arrayCharacters[0];
					if(leChar != null) {
						arrayCharacters.remove(leChar);
						leChar.kill();
						remove(leChar);
						leChar.destroy();
					}
				}
				finishThing();
				kill();
			}
		}
		super.update(elapsed);
	}

	var lastCharacter:Int = -1;
	var lastBoxType:String = '';
	function startNextDialog():Void
	{
		var curDialogue:DialogueLine = null;
		do {
			curDialogue = dialogueList.dialogue[currentText];
		} while(curDialogue == null);

		if(curDialogue.text == null || curDialogue.text.length < 1) curDialogue.text = ' ';
		if(curDialogue.boxState == null) curDialogue.boxState = 'normal';
		if(curDialogue.speed == null || Math.isNaN(curDialogue.speed)) curDialogue.speed = 0.05;

		var animName:String = curDialogue.boxState;
		var boxType:String = textBoxTypes[0];
		for (i in 0...textBoxTypes.length) {
			if(textBoxTypes[i] == animName) {
				boxType = animName;
			}
		}

		var character:Int = 0;
		box.visible = true;
		for (i in 0...arrayCharacters.length) {
			if(arrayCharacters[i].curCharacter == curDialogue.portrait) {
				character = i;
				break;
			}
		}
		var centerPrefix:String = '';
		var lePosition:String = arrayCharacters[character].jsonFile.dialogue_pos;
		if(lePosition == 'center') centerPrefix = 'center-';

		if(character != lastCharacter) {
			box.animation.play(centerPrefix + boxType + 'Open', true);
			updateBoxOffsets(box);
			box.flipX = (lePosition == 'left');
		} else if(boxType != lastBoxType) {
			box.animation.play(centerPrefix + boxType, true);
			updateBoxOffsets(box);
		}
		lastCharacter = character;
		lastBoxType = boxType;

		if(daText != null) {
			daText.killTheTimer();
			daText.kill();
			remove(daText);
			daText.destroy();
		}

		textToType = curDialogue.text;
		daText = new Alphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, textToType, false, true, curDialogue.speed, 0.7);
		add(daText);

		var char:DialogueCharacter = arrayCharacters[character];
		if(char != null) {
			char.playAnim(curDialogue.expression, daText.finishedText);
			if(char.animation.curAnim != null) {
				var rate:Float = 24 - (((curDialogue.speed - 0.05) / 5) * 480);
				if(rate < 12) rate = 12;
				else if(rate > 48) rate = 48;
				char.animation.curAnim.frameRate = rate;
			}
		}
		currentText++;

		if(nextDialogueThing != null) {
			nextDialogueThing();
		}
	}

	public static function parseDialogue(path:String):DialogueFile {
		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end
		return cast Json.parse(rawJson);
	}

	public static function updateBoxOffsets(box:FlxSprite) { //Had to make it static because of the editors
		box.centerOffsets();
		box.updateHitbox();
		if(box.animation.curAnim.name.startsWith('angry')) {
			box.offset.set(50, 65);
		} else if(box.animation.curAnim.name.startsWith('center-angry')) {
			box.offset.set(50, 30);
		} else {
			box.offset.set(10, 0);
		}
		
		if(!box.flipX) box.offset.y += 10;
	}
}
