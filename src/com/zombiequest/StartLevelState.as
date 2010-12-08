package com.zombiequest 
{
	import adobe.utils.CustomActions;
	
	import com.zombiequest.power.*;
	
	import org.flixel.*;
	import org.flixel.data.FlxAnim;
	
	/**
	 * ...
	 * @author Team Zombie Quest
	 */
	public class StartLevelState extends FlxState 
	{
		private const maxHealth:Number = 100;
		private var player:Player;
		private var coin:Coin;
		public static var enemyGroup:FlxGroup;
		public static var bulletGroup:FlxGroup;
		public static var innocentGroup:FlxGroup;
		public static var minionGroup:FlxGroup;
		public static var collideGroup:FlxGroup;
		private var minionFactory:MinionFactory;
		private var enemyFactory:EnemyFactory;
		private var level:Map;
		private var currentPower:PowerEffect;
		public static var hudManager:HUDMaker;
		private const attackTimeout:Number = 0.5;
		
		/**Number of seconds between release of enemies 
		 * Assumes constant time between waves
		 */
		private const WAVE_TIMEOUT:Number=20;
		
		
		private var decayRate:Number = 10;
		private var decayTimeout:Number = 10;
		private var decayClock:Number = 0;
		private var waveTimer:Number = WAVE_TIMEOUT;
		private var attackTimer:Number = attackTimeout;
		
		override public function create():void
		{
			//Instantiate objects
			bulletGroup = new FlxGroup();
			enemyGroup = new FlxGroup();
			innocentGroup = new FlxGroup();
			minionGroup = new FlxGroup();
			collideGroup = new FlxGroup();
			level = new Level_Group1(true, onAddSprite);
			minionFactory = new MinionFactory(player);
			enemyFactory = new EnemyFactory(minionGroup, player);
			
			add(bulletGroup);
			addEnemyCollision();
			collideGroup.add(innocentGroup);
			collideGroup.add(minionGroup);
			
			enemyFactory.startHorde();
			
			var innocent:Innocent = new Innocent(480, 400, 0);
			add(innocent);
			innocentGroup.add(innocent);
			
			//Set up the camera
			FlxG.follow(player, 2.5);
			FlxG.followAdjust(.5, .2);
			FlxG.followBounds(Map.boundsMinX, Map.boundsMinY, Map.boundsMaxX, Map.boundsMaxY);
			FlxG.mouse.hide();
			hudManager = new HUDMaker();
		}
		
		override public function update():void
		{
			FlxU.collide(level.hitTilemaps, collideGroup);
			FlxU.collide(level.hitTilemaps, player);
			collideGroup.collide();
			player.collide(enemyGroup);
			player.collide(innocentGroup);
			FlxU.overlap(player, bulletGroup, playerGotShot);
			overlapBullets();
			playerAttack();
			enemyShoot();
			armyControl();
			zombieDecay();
			updateHealthBar();
			updateWaveStatus();
			super.update();
		}
		
		protected function onAddSprite(obj:Object, layer:FlxGroup, level:Map, properties:Array):Object
		{
			if (obj is Player) {
				player = obj as Player;
			}
			return obj;
		}
		
		protected function gotTheCoin(...rest):void
		{
			FlxG.state = new EndState("You Won, fuck yeah!!");
		}
		
		protected function attackEnemy(overlap:Object, e:Object):void
		{
			var enemy:Enemy = e as Enemy;
			enemy.health -= player.damage;
			enemy.updateHealthbar();
			if (enemy.dead) {
				player.health += Enemy.healthRegen;
				minionFactory.getMinion(enemy.x, enemy.y);
			}
		}
		protected function attackInnocent(overlap:Object, i:Object):void
		{
			var innocent:Innocent = i as Innocent;
			innocent.kill();
			player.health += Innocent.healthRegen;
			minionFactory.getMinion(innocent.x, innocent.y);
		}
		
		protected function playerGotShot(p:FlxObject, b:FlxObject):void
		{
			player.health -= 10;
			b.kill();
		}
		
		protected function zombieDecay():void
		{
			decayClock += FlxG.elapsed;
			if (decayClock > decayTimeout) 
			{
				player.health -= decayRate;
				var minions:Array = minionGroup.members;
				for (var i:Number = 0; i < minions.length; i++)
				{
					var minion:Minion = minions[i] as Minion;
					minion.health -= decayRate;
					if (minion.health <= 0)
					{
						minion.kill();
						minionGroup.remove(minion, true);
					}
				}
				decayClock = 0;
			}
		}

		/** 
		 * Keep track of when the next wave should come and trigger it
		 */
		protected function updateWaveStatus():void
		{
			//I like how some timers go from TIMEOUT to 0, others go from 0 to TIMEOUT
			waveTimer -= FlxG.elapsed;
			if (waveTimer <=0) 
			{
				waveTimer = WAVE_TIMEOUT;
				//triggerWave();
				enemyFactory.startHorde();
			}
		}
		
		
		protected function overlapBullets():void
		{
			var bullets:Array = bulletGroup.members;
			for (var i:Number = 0; i < bullets.length; i++)
			{
				var bullet:Bullet = bullets[i] as Bullet;
				if (level.hitTilemaps.collide(bullet)) {
					bullet.kill();
				}
			}
		}
		
		protected function enemyShoot():void
		{
			var enemyA:Array = enemyGroup.members;
			for each (var enemy:Enemy in enemyA) {
				if (enemy.shooting && !enemy.dead && !player.dead) {
					enemy.lastShot += FlxG.elapsed;
					if (enemy.lastShot >= enemy.shotTimeout) {
						var p:FlxPoint = enemy.bulletSpawn();
						var a:Number = FlxU.getAngle(player.x - p.x, player.y - p.y);
						bulletGroup.add(new Bullet(p, a));
						enemy.lastShot = 0;
					}
				}
			}
		}
		
		protected function updatePower():void
		{
			if (currentPower == null)
			{
				return;
			}
			currentPower.updateTime();
			if (!currentPower.isActive()) {
				hudManager.clearStatusText();
			}
			else
			{
				hudManager.updatePowerTimer(currentPower.timeRemaining());
			}
		}
		/**
		 * 
		 *
		 * Call whenever the player's health is changed
		 * CHANGE: Now called from update, doesn't need to be called elsewhere
		 */
		protected function updateHealthBar():void
		{
			if (player.health > maxHealth) {
				player.health = maxHealth;
			}
			if (player.health <= 0) {
				player.kill();
				hudManager.setHealth(0);
				FlxG.state = new EndState("You Lost!");
			}
			hudManager.setHealth(player.health);
		}
		
		protected function playerAttack():void
		{
			attackTimer += FlxG.elapsed;
			if (FlxG.keys.justPressed("SPACE"))
			{
				if (attackTimer >= attackTimeout) 
				{
					FlxU.overlap(player.overlap, enemyGroup, attackEnemy);
					FlxU.overlap(player.overlap, innocentGroup, attackInnocent);
					attackTimer = 0;
				}
			}
		}
		
		protected function armyControl():void
		{
			var minion:Minion = null;
			if (FlxG.keys.justPressed("A")) 
			{
				minion = nextMinion();
				if (minion != null)
				{
					minion.state == Minion.ATTACKING;
					minion.findTarget();
				}
			}
			else if (FlxG.keys.justPressed("S"))
			{
				minion = nextMinion();
				if (minion != null)
				{
					minion.state = Minion.SENTRY;
				}
			}
			else if (FlxG.keys.justPressed("D"))
			{
				var minions:Array = minionGroup.members;
				for (var i:Number = 0; i < minions.length; i++)
				{
					Minion(minions[i]).state = Minion.DEFENDING;
				}
			}
		}
		/**
		 * Finds the next minion with the DEFENDING state
		 */
		protected function nextMinion():Minion
		{
			var minions:Array = minionGroup.members;
			for (var i:Number = 0; i < minions.length; i++)
			{
				var minion:Minion = minions[i] as Minion;
				if (minion.state == Minion.DEFENDING && !minion.dead)
				{
					return minion;
				}
			}
			return null;
		}
		
		public function addEnemyCollision(enemy:Enemy = null):void
		{
			if (enemy != null)
			{
				collideGroup.add(enemy.collideArea);
			}
			else{
				var enemies:Array = enemyGroup.members;
				for (var i:Number = 0; i < enemies.length; i++)
				{
					collideGroup.add(Enemy(enemies).collideArea);
				}
			}
		}
	}

}