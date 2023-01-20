/// Contains game logic
module qonquest2.logic;

import qonquest2.map, qonquest2.app, qonquest2.localization, qonquest2.window;
import std.algorithm, std.format, std.conv;

/// Represents a player
class Player {
	Country country;  /// Country the player has chosen
	Action[] actions; /// Actions the player has done

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
		if(source.owner is dest.owner || dest.troops == 0) {
			// just a movement between provinces
			source.troops -= amt;
			dest.troops   += amt;
			return;
		}
		auto attacker = source.owner;
		auto defender = dest.owner;
		// battle!
		string battleLog; // log to show if the player owns one of the provinces
		battleLog ~= attacker.hexCode~localization[attacker.name]~"`FFFFFF"~localization["vs"]~defender.hexCode~localization[defender.name]~"\n";
		import std.random : uniform;
		int roll() {
			return uniform(0, 6)+1;
		}
		int round = 1;
		int totalAttackerLost = 0;
		while(true) {
			battleLog ~= "`FFFFFF"~localization["round"]~" "~round.to!string~"\n";
			int[] attackerRolls = [roll, roll].sort!"a > b".release;
			int[] defenderRolls = [roll, roll, roll].sort!"a > b".release;
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
			battleLog ~= localization["losses"].format(attackerLost, defenderLost);
			totalAttackerLost -= attackerLost;
			dest.troops -= defenderLost;
			round++;
			void won(Country c) {
				battleLog ~= localization["battle-result"].format("`"~c.hexCode~localization[c.name]~"`FFFFFF")~"\n";
				dest.owner = c;
				if(attacker is c || defender is c) {
					auto win = new Window(100, 100, 200, 600, localization["battle-of"]~" "~source.hexCode~localization[source.name]);
					win.addWidget(new Text(win, 0, 0, battleLog));
					   .addWidget(new XButton(win));
					windows ~= win;
				}
			}
			if(totalAttackerLost > amt) {
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

/// Ends the turn and runs each action. If this is the last player, then it runs AI too
void endTurn() {
	foreach(a; player.actions) {
		a.commit();
	}
	player.actions = [];
	if(currentPlayer+1 == players.length) {
		// TODO: AI
		foreach(c; countries) {
			c.deployableTroops = cast(int)c.ownedProvinces.length*2;
		}
		currentPlayer = 0;
		return;
	}
	currentPlayer++;
}