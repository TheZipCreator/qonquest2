/// Contains game logic
module qonquest2.logic;

import qonquest2.map;

/// Represents a player
struct Player {
	Country country;  /// Country the player has chosen
	Action[] actions; /// Actions the player has done
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
		source.troops -= amt;
		dest.troops   += amt;
	}
}

/// Deploys troops to a province
class DeployAction : Action {
	Province province;
	int amt;

	this(typeof(this.tupleof) t) {
		this.tupleof = t;
	}

	void commit() {
		province.troops += amt;
	}
}