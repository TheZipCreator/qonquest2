/// Contains game logic
module qonquest2.logic;

import qonquest2.map, qonquest2.app, qonquest2.localization;
import std.algorithm, std.format;

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
		if(source.owner is dest.owner) {
			// just a movement between provinces
			source.troops -= amt;
			dest.troops   += amt;
			return;
		}
		// battle!
		string battleLog; // log to show if the player owns one of the provinces
		battleLog ~= localization["battle-of"]~" "~source.hexCode~localization[source.name];
		battleLog ~= source.owner.hexCode~localization[source.owner.name]~"`FFFFFF"~localization["versus"]~dest.owner.hexCode~localization[dest.owner.name]~"\n";
		import std.random : uniform;
		int roll() {
			return uniform(0, 6)+1;
		}
		int round = 1;
		while(true) {
			battleLog ~= "`FFFFFF"~localization["round"]~" "~round.to!string~"\n";
			int[] attackerRolls = [roll, roll].sort!"a > b".release;
			int[] defenderRolls = [roll, roll, roll].sort!"a > b".release;
			int attackerLost;
			int defenderLost;
			for(i; 0..2) {
				if(attackerRolls[i] > defenderRolls[i])
					defenderLost++;
				else
					attackerLost++;
			}
			battleLog ~= localization["attacker-rolls"]~": "~format("%d, %d, %d\n", attackerRolls[0], attackerRolls[1], attackerRolls[2]);
			battleLog ~= localization["defender-rolls"]~": "~format("%d, %d\n", defenderRolls[0], defenderRolls[1]);
			source.troops -= attackerLost;
			dest.troops -= defenderLost;
			round++;
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
		currentPlayer = 0;
		return;
	}
	currentPlayer++;
}