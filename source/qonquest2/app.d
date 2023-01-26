/// Contains main and input handling
module qonquest2.app;

import arsd.simpledisplay;

import std.stdio, std.algorithm, std.array;

import qonquest2.display, qonquest2.map, qonquest2.window, qonquest2.localization, qonquest2.logic;
import qonquest2.window : Window;

SimpleWindow win;
Window heldWindow;   /// Currently held window. null if no window is being held
Point heldWindowPos; /// Where the held window is being dragged from

// main menu windows
Window mainMenuWindow;

// game windows
Window viewWindow;
Window actionsWindow;
Window howToPlayWindow;

/// Controls the state of the game
enum State {
	MAIN_MENU, GAME
}
State state; /// The current state

Player[] players;     /// Players in the game
size_t currentPlayer; /// Current player

/// gets the current player
Player player() {
	if(players[currentPlayer] is null)
		throw new Exception("Player is null!");
	return players[currentPlayer];
}

/// Controls the current map mode
enum MapMode {
	// normal map modes
	PROVINCE, COUNTRY, 
	// selection map modes
	SELECT_COUNTRY, MOVE_TROOPS_1, MOVE_TROOPS_2, DEPLOY_TROOPS,
	// other map modes
	WON, LOST
}
Province selectedProvince; /// Interim value for moving troops
MapMode mapMode;           /// The current map mode
MapMode prevMapMode;       /// The previous map mode

void main(string[] args) {
	win = new SimpleWindow(WIDTH, HEIGHT, "Qonquest 2", OpenGlOptions.yes, Resizability.automaticallyScaleIfPossible);
	loadMap();
	loadLocalization("eng");
	import std.functional : toDelegate;
	changeState(State.MAIN_MENU);
	// start event loop
	win.redrawOpenGlScene = (&redrawOpenGlScene).toDelegate;
	win.eventLoop(16, (&redraw).toDelegate, (&keyEvent).toDelegate, (&mouseEvent).toDelegate);
}

/// Changes the current state
void changeState(State newState) {
	windows = [];
	state = newState;
	final switch(state) {
		case State.MAIN_MENU:
			mainMenuWindow = new Window(WIDTH/4, HEIGHT/4, 600, 400, "main-menu");
			mainMenuWindow.addWidget(new Button(mainMenuWindow, 50, 50, 500, 24, "play", () {
				changeState(State.GAME);
				mapMode = MapMode.SELECT_COUNTRY;
			}));
			windows = [mainMenuWindow];
			break;
		case State.GAME:
			actionsWindow = new Window(300, 50, 300, 500, "actions");
			actionsWindow
			.addWidget(new Button(actionsWindow, 10, 500-30, 280, 24, "end-turn", () {
				endTurn();
			}))
			.addWidget(new Button(actionsWindow, 10, 500-30*2, 280, 24, "undo-action", () {
				if(player.actions.length > 0) {
					auto action = player.actions[0];
					if(auto da = cast(DeploymentAction)action)
						player.country.deployableTroops += da.amt;
					player.actions = player.actions[0..$-1];
				}
			}))
			.addWidget(new CountButton(actionsWindow, 10, 500-30*3, 280, 24, "move-troops", 1, int.max, (int amt) {
				prevMapMode = mapMode;
				mapMode = MapMode.MOVE_TROOPS_1;		
				availableProvinces = provinces.filter!(p => p !is null && p.owner == player.country && p.effectiveTroops >= amt).array;
				troopAmt = amt;
			}))
			.addWidget(new CountButton(actionsWindow, 10, 500-30*4, 280, 24, "deploy-troops", 0, int.max, (int amt) {
				if(amt < 1)
					return;
				availableProvinces = player.country.ownedProvinces();
				prevMapMode = mapMode;
				mapMode = MapMode.DEPLOY_TROOPS;
				troopAmt = amt;
			}))
			.addWidget(new ActionBox(actionsWindow));

			import std.string : splitLines;
			howToPlayWindow = new Window(800, 50, 300, cast(int)(localization["how-to-play-file"].splitLines.length*CHAR_SIZE), "how-to-play");
			howToPlayWindow
			.addWidget(new Text(howToPlayWindow, 0, 0, localization["how-to-play-file"]));

			viewWindow = new Window(50, 200, 150, 200, "view");
			viewWindow
			.addWidget(new Checkbox(viewWindow, 10, 10, "actions", &actionsWindow.visible))
			.addWidget(new Checkbox(viewWindow, 10, 10+(Checkbox.SIZE+10), "how-to-play", &howToPlayWindow.visible))
			.addWidget(new Checkbox(viewWindow, 10, 200-(Checkbox.SIZE+10)*2, "hide-straits", &hideStraits))
			.addWidget(new Checkbox(viewWindow, 10, 200-(Checkbox.SIZE+10), "provinces", () {
				mapMode = mapMode.PROVINCE;
			}, () {
				mapMode = mapMode.COUNTRY;
			}));

			windows = [viewWindow, actionsWindow, howToPlayWindow];
	}
}

void redraw() {
	win.redrawOpenGlSceneSoon();
	if(players.length > 0 && actionsWindow !is null) {
		(cast(CountButton)actionsWindow.getWidget("deploy-troops")).max = player.country.deployableTroops;
	}
}

bool shiftPressed; /// Whether or not shift is pressed

void keyEvent(KeyEvent e) {
	if(e.key == Key.Shift) {
		shiftPressed = e.pressed;
	}
	final switch(state) {
		case State.MAIN_MENU:
			break;
		case State.GAME:
			switch(mapMode) {
				case MapMode.MOVE_TROOPS_1:
				case MapMode.MOVE_TROOPS_2:
				case MapMode.DEPLOY_TROOPS:
					if(e.key == Key.Escape) {
						mapMode = prevMapMode;
					}
					break;
				case MapMode.WON:
				case MapMode.LOST:
					loadMap();
					changeState(State.MAIN_MENU);
					break;
				default:
					break;
			}
	}
}

Province[] availableProvinces; /// Available provinces in doing actions
int troopAmt;                  /// Troop amount for deployment and movement

void mouseEvent(MouseEvent e) {
	alias MET = MouseEventType;
	final switch(e.type) {
		case MET.buttonPressed:
			if(state != State.GAME || [MapMode.PROVINCE, MapMode.COUNTRY].canFind(mapMode))
				foreach(i, w; windows) {
					if(!w.visible)
						continue;
					if(w.click(e.x-w.x, e.y-w.y, e.button))
						break;
					if(w.inTitleBar(e.x, e.y)) {
						heldWindow = w;
						heldWindowPos = Point(e.x-w.x, e.y-w.y);
						windows = w~windows[0..i]~windows[i+1..$];
						break;
					}
				}
			else if(state == State.GAME) {
				Province clickedProvince;
				outer:
				foreach(p; provinces)
					foreach(pix; p.pixels)
						if(pix.x == e.x && pix.y == e.y) {
							clickedProvince = p;
							break outer;
						}
				switch(mapMode) {
					case MapMode.SELECT_COUNTRY:
						if(clickedProvince !is null) {
							players = [new Player(clickedProvince.owner)];
							mapMode = MapMode.COUNTRY;
							foreach(p; provinces)
								if(!p.owner.isPlayerCountry)
									p.troops = 2;
								else
									p.troops = 0;
						}
						break;
					case MapMode.MOVE_TROOPS_1:
						if(availableProvinces.canFind(clickedProvince)) {
							selectedProvince = clickedProvince;
							mapMode = MapMode.MOVE_TROOPS_2;
							availableProvinces = provinces.filter!(p => p !is null && selectedProvince.neighbors.canFind(p)).array;
						}
						break;
					case MapMode.MOVE_TROOPS_2:
						if(availableProvinces.canFind(clickedProvince)) {
							mapMode = prevMapMode;
							player.actions ~= new MovementAction(selectedProvince, clickedProvince, troopAmt);
						}
						break;
					case MapMode.DEPLOY_TROOPS:
						if(availableProvinces.canFind(clickedProvince)) {
							mapMode = prevMapMode;
							player.actions ~= new DeploymentAction(clickedProvince, troopAmt);
							player.country.deployableTroops -= troopAmt;
						}
						break;
					default:
						break;
				}
			}
			break;
		case MET.buttonReleased:
			switch(e.button) {
				case MouseButton.left:
					if(heldWindow !is null)
						heldWindow = null;
					break;
				default:
					break;
			}
			break;
		case MET.motion:
			if(heldWindow !is null) {
				heldWindow.x = e.x-heldWindowPos.x;
				heldWindow.y =  e.y-heldWindowPos.y;
			}
			break;
	}
}
