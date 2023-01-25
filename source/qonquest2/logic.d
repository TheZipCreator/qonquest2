/// Contains game logic
module qonquest2.logic;

import qonquest2.map, qonquest2.app, qonquest2.localization, qonquest2.window;
import qonquest2.display : CHAR_SIZE;
import std.algorithm, std.format, std.conv, std.typecons, std.random, std.string;

/// Represents a player
class Player {
	Country country;  /// Country the player has chosen
	Action[] actions; /// Actions the player has done
	bool hasCapturedProvince; /// Whether the player has captured a province yet

	this(Country country) {
		this.country = country;
	}
}

/// Represents a single action that can be done
interface Action {
	void commit();   /// Does the action
}

/// Moves troops from one province to another
class MovementAction : Action {
	Province source; /// Source province
	Province dest;   /// Destination province
	int amt;         /// Amount of troops to move

	this(typeof(this.tupleof) t) {
		this.tupleof = t;
	}	
	
	void commit() {
		if(source.owner is dest.owner) {
			// just a movement between provinces
			source.troops -= amt;
			dest.troops   += amt;
			return;
		}
		auto attacker = source.owner;
		auto defender = dest.owner;
		// battle!
		string battleLog; // log to show if the player owns one of the provinces
		battleLog ~= "`o"~attacker.hexCode~localization[attacker.name]~"`o`FFFFFF"~localization["vs"]~"`o"~defender.hexCode~localization[defender.name]~"`o`FFFFFF\n";
		import std.random : uniform;
		int roll(Country c) {
			if(auto p = c.getPlayer())
				if(!p.hasCapturedProvince)
					return uniform(2, 6)+1;
			return uniform(0, 6)+1;
		}
		int round = 1;
		int totalAttackerLost = 0;
		void won(Country c) {
			if(auto p = c.getPlayer())
				p.hasCapturedProvince = true;
			battleLog ~= localization["battle-result"].format("`o"~c.hexCode~localization[c.name]~"`o`FFFFFF")~"\n";
			dest.owner = c;
			if(!attacker.isPlayerCountry && !defender.isPlayerCountry)
				return;
			int height = 40+cast(int)(battleLog.splitLines.length)*CHAR_SIZE; 
			auto win = new Window(500, height, localization["battle-of"]~" `o"~dest.hexCode~localization[dest.name]);
			win .addWidget(new Text(win, 0, 34, battleLog))
					.addWidget(new Button(win, 10, 10, 480, 24, "close", () {
						win.close = true;	 
					}));
			windows = win~windows;
		}
		if(dest.troops == 0) {
			won(attacker);
			source.troops -= amt;
			dest.troops = amt;
			return;
		}
		while(true) {
			battleLog ~= "`FFFFFF"~localization["round"]~" "~round.to!string~"\n";
			battleLog ~= "`o"~attacker.hexCode~(amt-totalAttackerLost).to!string~"`o`FFFFFF / `o"~dest.hexCode~dest.troops.to!string~"`o`FFFFFF\n";
			int[] attackerRolls = [roll(attacker), roll(attacker)].sort!"a > b".release;
			int[] defenderRolls = [roll(defender), roll(defender), roll(defender)].sort!"a > b".release;
			int attackerLost;
			int defenderLost;
			foreach(i; 0..2) {
				if(attackerRolls[i] > defenderRolls[i])
					defenderLost++;
				else
					attackerLost++;
			}
			battleLog ~= localization["attacker-rolls"]~": "~format("%d, %d\n", attackerRolls[0], attackerRolls[1]);
			battleLog ~= localization["defender-rolls"]~": "~format("%d, %d, %d\n", defenderRolls[0], defenderRolls[1], defenderRolls[2]);
			battleLog ~= localization["losses"].format(attackerLost, defenderLost)~"\n";
			totalAttackerLost += attackerLost;
			dest.troops -= defenderLost;
			round++;
			if(totalAttackerLost >= amt) {
				won(defender);
				source.troops -= amt;
				break;
			}
			else if(dest.troops <= 0) {
				won(attacker);
				dest.troops = amt-totalAttackerLost;
				source.troops -= amt;
				break;
			}
		}
	}
}

/// Deploys troops to a province
class DeploymentAction : Action {
	Province province;
	int amt;

	this(typeof(this.tupleof) t) {
		this.tupleof = t;
	}

	void commit() {
		province.troops += amt;
	}
}

/// Returns the amount of troops a province has after movement & deployment
int effectiveTroops(Province p) {
	int amt = p.troops;
	foreach(a; player.actions) {
		if(auto ma = cast(MovementAction)a) {
			if(ma.source is p)
				amt -= ma.amt;
		} else if(auto da = cast(DeploymentAction)a) {
			if(da.province is p)
				amt += da.amt;
		}
	}
	return amt;
}

/// Returns the player associated with a given country (null if none)
Player getPlayer(Country c) {
	foreach(p; players)
		if(p.country is c)
			return p;
	return null;
}

/// Tests if a country is the player country
bool isPlayerCountry(Country c) {
	return c.getPlayer() !is null;
}

/// Commits all actions in an array
void commit(Action[] actions) {
	foreach(a; actions)
		a.commit;
}

int currentTurn = 0; /// The current turn

/// Ends the turn and runs each action. If this is the last player, then it runs AI too
void endTurn() {
	player.actions.commit();
	player.actions = [];
	if(currentPlayer+1 == players.length) {
		foreach(c; countries) {
			c.deployableTroops = cast(int)c.ownedProvinces.length*2;
			if(!c.isPlayerCountry)
				c.runAI();
		}
		currentPlayer = 0;
		currentTurn++;
	} else
		currentPlayer++;
	if(player.country.ownedProvinces.length == 0)
		mapMode = MapMode.LOST;
	else if(player.country.ownedProvinces.length == provinces.length)
		mapMode = MapMode.WON;
}

alias Frontier = Tuple!(Province, "src", Province, "dest");

/// Gets the frontiers of a country (e.g. provinces that neighbor provinces not owned by the country)
Frontier[] frontiers(Country c) {
	Frontier[] frontiers;
	foreach(src; c.ownedProvinces)
		foreach(dest; src.neighbors)
			if(src.owner !is dest.owner)
				frontiers ~= Frontier(src, dest);
	return frontiers;
}

/// Runs the AI for a country
void runAI(Country c) {
	Action[] actions;
	import std.array;
	auto frontiers = c.frontiers.randomShuffle.array;
	// deployment
	while(c.deployableTroops > 0) {
		actions ~= new DeploymentAction(frontiers.choice.src, 1);
		c.deployableTroops--;
	}
	// movement
	Province[] hasMovedFrom;
	foreach(f; frontiers) {
		if(hasMovedFrom.canFind(f.src))
			continue;
		if(f.dest.troops > f.src.troops)
			continue;
		actions ~= new MovementAction(f.src, f.dest, f.src.troops);
		hasMovedFrom ~= f.src;
	}
	actions.commit();
}
