package com.zombiequest 
{
	/**
	 * ...
	 * @author Team Zombie Quest
	 */
	import org.flixel.*;
	public class Minion extends FlxSprite
	{
		private var speed:Number = 90;
		private var attackRange:Number = 20;
		private var followRange:Number = 100;
		private var playerFollowMin:Number = 64;
		private var damage:Number = 25;
		private const attackTimeout:Number = 1;
		private var attackTimer:Number = 0;
		private var enemyGroup:FlxGroup;
		private var innocentGroup:FlxGroup;
		private var player:Player;
		private var chasing:Boolean = false;
		private var chaseTarget:FlxSprite;
		private static var id:Number = 0;
		
		/*
		 * State Enums
		 */
		public static const ATTACKING:Number = 1;
		public static const FOLLOWING:Number = 2;
		public static const SENTRY:Number = 3;
		
		private var state:Number;
		/**
		 * Should only be called by the MinionFactory
		 */
		public function Minion(x:Number, y:Number, enemyGroup:FlxGroup, innocentGroup:FlxGroup, player:Player) 
		{
			this.enemyGroup = enemyGroup;
			this.innocentGroup = innocentGroup;
			this.player = player;
			id++;
			super(x, y);
		}
		
		public override function update():void
		{
			var angle:Number;
			var dist:Number;
			velocity.x = 0;
			velocity.y = 0;
			attackTimer += FlxG.elapsed;
			var pCenter:FlxPoint = player.center();
			if (!chasing || chaseTarget.dead) {
				var targets:Array = enemyGroup.members;
				targets = targets.concat(innocentGroup.members);
				for (var i:Number = 0; i < targets.length; i++ && !chasing) {
					if (MathU.dist(x - FlxSprite(targets[i]).x, y - FlxSprite(targets[i]).y) < followRange)
					{
						if (!FlxSprite(targets[i]).dead) {
							chasing = true;
							chaseTarget = targets[i] as FlxSprite;
						}
					}
				}
				if (!chasing || chaseTarget.dead) {
					angle = FlxU.getAngle(pCenter.x - x, pCenter.y - y);
					dist = MathU.dist(pCenter.x - x, pCenter.y - y);
					if (dist > playerFollowMin) 
					{
						velocity.x = speed * Math.cos(MathU.degToRad(angle));
						velocity.y = speed * Math.sin(MathU.degToRad(angle));
					}
				}
			}
			
			if (chasing && !chaseTarget.dead) {
				angle = FlxU.getAngle(chaseTarget.x - x, chaseTarget.y - y);
				this.angle = angle;
				dist = MathU.dist(chaseTarget.x - x, chaseTarget.y - y);
				if (dist <= attackRange) {
					attack();
				}
				velocity.x = speed * Math.cos(MathU.degToRad(angle));
				velocity.y = speed * Math.sin(MathU.degToRad(angle));
			}
			super.update();
		}
		private function attack():void
		{
			if (attackTimer >= attackTimeout)
			{
				chaseTarget.health -= damage;
				attackTimer = 0;
				if (chaseTarget.health <= 0)
				{
					chaseTarget.kill();
				}
			}
		}
	}
}
