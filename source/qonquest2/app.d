/// Contains main and input handling
module qonquest2.app;

import arsd.simpledisplay;

import std.stdio;

import qonquest2.display, qonquest2.map, qonquest2.window, qonquest2.localization;
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
			mainMenuWindow = new Window(WIDTH/4, HEIGHT/4, WIDTH/2, HEIGHT/2, "main-menu");
			windows = [mainMenuWindow];
			break;
		case State.GAME:
			actionsWindow = new Window(300, 50, 150, 200, "actions");
			viewWindow = new Window(50, 50, 100, 200, "view");
			viewWindow.addWidget(new Checkbox(viewWindow, 10, 10, "actions", &actionsWindow.visible));
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
			foreach(w; windows) {
				if(!w.visible)
					continue;
				if(w.click(e.x-w.x, e.y-w.y, e.button))
				 	break;
				if(w.inTitleBar(e.x, e.y)) {
					heldWindow = w;
					heldWindowPos = Point(e.x-w.x, e.y-w.y);
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
