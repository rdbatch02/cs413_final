package com.defense.haxe.tower;

import starling.textures.Texture;
import starling.display.Sprite;
import starling.events.TouchEvent;
import starling.events.Touch;

import com.defense.haxe.Root;
import com.defense.haxe.tower.Tower;

class TowerGrid extends Sprite{
	/* Tower textures */
	private var T_BLOCK:Texture = Root.assets.getTexture("block");
	private var T_ACTIVE_BLOCK:Texture = Root.assets.getTexture("block_active");

	private var T_B0:Texture  = Root.assets.getTexture("border_0");
	private var T_B1:Texture  = Root.assets.getTexture("border_1");
	private var T_B2:Texture  = Root.assets.getTexture("border_2");
	private var T_B2P:Texture = Root.assets.getTexture("border_2p");
	private var T_B3:Texture  = Root.assets.getTexture("border_3");
	
	/* Keep track of tile sizing */
	private var tileSize:Int;			// How big the tiles will be (excluding border)
	private var halfTileSize:Float;		// Half of the tile's true size, because screw division
	private var tileBorder:Int; 		// How big the border is around the tiles
	private var actualTileSize:Int;		// The actual size of each tile, including the border (tileSize + tileBorder*2)
	
	/* Keep track of the towers */
	private var numWidth:Int;
	private var numHeight:Int;
	private var a_Tower:Array<Tower>;
	
	public function new(tileSize:Int, tileBorder:Int, numWidth:Int, numHeight:Int){
		super();
		
		this.tileSize = tileSize;
		this.tileBorder = tileBorder;
		this.halfTileSize = tileSize / 2.0;
		this.actualTileSize = tileSize + tileBorder*2;
		
		this.numWidth = numWidth;
		this.numHeight = numHeight;
		this.width = numWidth*tileSize;
		this.height = numHeight*tileSize;
		
		// Initiate the tower array;
		a_Tower = new Array<Tower>();
		for(i in 0...numWidth*numHeight)
			a_Tower.push(null);
		
		// Populate the tower grid()
		populateGrid();
		this.towerTouch(0,0);
		
		this.addEventListener(TouchEvent.TOUCH, onTouch);
	}
	
	private function populateGrid(){
		var halfSize = Math.ceil(actualTileSize/2);
		for(x in 0...numWidth)
			for(y in 0...numHeight){
				var tower = new Tower(T_BLOCK, actualTileSize, x, y, x+y*numWidth);
				tower.x = x*(tileSize + tileBorder) + halfSize;
				tower.y = y*(tileSize + tileBorder) + halfSize;
				a_Tower[x + y*numWidth] = tower;
				addChild(tower);
			}
	}
	
	public function towerTouch(x:Int,y:Int){
		var tower = towerAt(x,y);
		
		// Debug reset path color...
		for(tower in a_Tower)
			tower.baseImage.color = 0xFFFFFF;
				
		// Hacky for now, but these are start / end points (for now)
		if(!(x == 0 && y == 0 || x == numWidth-1 && y == numHeight-1)){
			if(!tower.isActive()){
				checkArea(x, y);
				tower.setTexture(T_B0);
				tower.setActive();
			} else {
				tower.setTexture(T_BLOCK);
				tower.setActive(false);
			}
		}
		
		var a_Traverse = pathFind(0,0,numWidth-1,numHeight-1);
			
		if(a_Traverse != null){
			for(tower in a_Traverse){
				tower.baseImage.color = 0x00FF00;
			}
		} else {
			// trace("No path.");
		}
	}

	public function checkArea(x:Int , y:Int){
		//Store the 3x3 grid in two arrays (probably could be done with a 2d array)
		var xArray: Array<Int> = [(x-1), x, (x+1)];
		var yArray: Array<Int> = [(y-1), y , (y+1)];
		//Iterate over the coordinates to find if any of them are towers as well.
		for(xPos in xArray){
			for(yPos in yArray){
				if(towerAt(xPos, yPos).isActive()){
					// This is a tower
				}
			}
		}
	}
	
	public function validLocation(x:Int,y:Int):Bool{
		return(x > -1 && x < numWidth && y > -1 && y < numHeight);
	}
	
	public function pathFind(startX:Int, startY:Int, endX:Int, endY:Int):List<Tower>{
		// Create the iterative list
		var a_Traverse:List<Tower> = new List<Tower>();
		
		// Reset the tower pathing variables
		for(tower in a_Tower){
			tower.prevTower = null;
			tower.distance = -1;
		}
		
		// Set up the first tower
		var startTower = towerAt(startX, startY);
		startTower.distance = 0;
		a_Traverse.add(startTower);
		
		var counter = 0;
		while(a_Traverse.length > 0){
			var tower = a_Traverse.first();
			var towerX = tower.getGridX();
			var towerY = tower.getGridY();
			
			pathFindCheckTower(tower, towerX+1, towerY, a_Traverse); // Right
			pathFindCheckTower(tower, towerX, towerY+1, a_Traverse); // Down
			pathFindCheckTower(tower, towerX-1, towerY, a_Traverse); // Left
			pathFindCheckTower(tower, towerX, towerY-1, a_Traverse); // Up
			a_Traverse.pop();
			counter++;
		}
		
		// Check to see if there is no path available
		var lastTower = towerAt(endX, endY);
		if(lastTower.distance == -1){
			return null;
		}
		
		// Populate the path list for returning
		a_Traverse.clear();
		a_Traverse.push( lastTower );
		while(a_Traverse.first() != startTower){
			a_Traverse.push( a_Traverse.first().prevTower );
		}
		
		//trace(counter, a_Traverse.length);
		return a_Traverse;
	}
	
	private function pathFindCheckTower(curTower:Tower, nextX:Int, nextY:Int, a_Traverse:List<Tower>){
		if(validLocation(nextX, nextY)){
			var tower = towerAt(nextX,nextY);
			
			if(!tower.isActive() && (tower.distance == -1 || tower.distance > curTower.distance+1)){
				tower.prevTower = curTower;
				tower.distance = curTower.distance + 1;
				a_Traverse.add(tower);
			}
		}
	}
	
	
	var prevX = -1;
	var prevY = -1;
	public function onTouch( event:TouchEvent ){
		var touch:Touch = event.touches[0];
		if(touch.phase == "began" || touch.phase == "moved" || touch.phase == "ended"){
			var towerX = Math.floor((touch.globalX - this.x)/(tileSize+tileBorder));
			var towerY = Math.floor((touch.globalY - this.y)/(tileSize+tileBorder));
			
			if(!(towerX == prevX && towerY == prevY && touch.phase != "began") && validLocation(towerX,towerY)){
				prevX = towerX;
				prevY = towerY;
				towerTouch(towerX, towerY);
			}
		}
	}
	
	public function towerAt(x:Int,y:Int):Tower{
		return a_Tower[x + y*numWidth];
	}
}