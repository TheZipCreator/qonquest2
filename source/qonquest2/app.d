/// Contains main and input handling
module qonquest2.app;

import arsd.simpledisplay;

import std.stdio;

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

/// Controls the state of the game
enum State {
	MAIN_MENU, GAME
}
State state; /// The current state

Player[] players;     /// Players in the game
size_t currentPlayer; /// Current player

/// Controls the current map mode
enum MapMode {
	// normal map modes
	PROVINCE, COUNTRY, 
	// selection map modes
	SELECT_COUNTRY, MOVE_TROOPS_1, MOVE_TROOPS_2
}
Province selectedProvince; /// Interim value for moving troops
MapMode mapMode;           /// The current map mode

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
			actionsWindow = new Window(300, 50, 150, 300, "actions");
			actionsWindow.addWidget(new Button(actionsWindow, 10, 230, 130, 24, "end-turn", () {
			               // TODO
			             }))
			             .addWidget(new Button(actionsWindow, 10, 230, 100, 24, "move-troops", () {
			               mapMode = MapMode.MOVE_TROOPS_1;		 
			             }));
			viewWindow = new Window(50, 50, 100, 200, "view");
			viewWindow.addWidget(new Checkbox(viewWindow, 10, 10, "actions", &actionsWindow.visible))
			          .addWidget(new Checkbox(viewWindow, 10, 200-Checkbox.SIZE-10, "provinces", () {
			            mapMode = mapMode.PROVINCE;
			          }, () {
			            mapMode = mapMode.COUNTRY;
			          }));
			windows = [viewWindow, actionsWindow];
	}
}

void redraw() {
	win.redrawOpenGlSceneSoon();
}

void keyEvent(KeyEvent e) {

}

void mouseEvent(MouseEvent e) {
	alias MET = MouseEventType;
	final switch(e.type) {
		case MET.buttonPressed:
			foreach_reverse(i, w; windows) {
				if(!w.visible)
					continue;
				if(w.click(e.x-w.x, e.y-w.y, e.button))
				 	break;
				if(w.inTitleBar(e.x, e.y)) {
					heldWindow = w;
					heldWindowPos = Point(e.x-w.x, e.y-w.y);
					windows = windows[0..i]~windows[i+1..$];
					windows ~= w;
					break;
				}
				if(state == State.GAME) {
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
								players ~= Player(clickedProvince.owner);
								mapMode = MapMode.COUNTRY;
							}
							break;
						case MapMode.MOVE_TROOPS_1:
							if(clickedProvince !is null) {
								selectedProvince = clickedProvince;
								mapMode = MapMode.MOVE_TROOPS_2;
							}
							break;
						case MapMode.MOVE_TROOPS_2:
							break;
						default:
							break;
					}
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
				auto newX = e.x-heldWindowPos.x;
				auto newY = e.y-heldWindowPos.y;
				if(newX >= 0 && newY >= 0 && newX < WIDTH-heldWindow.width && newY < HEIGHT-heldWindow.height) {
					heldWindow.x = newX;
					heldWindow.y = newY;
				}
			}
			break;
	}
}
