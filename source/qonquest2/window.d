/// Contains code handling windows and widgets
module qonquest2.window;

import qonquest2.display;
import arsd.simpledisplay;

abstract class Widget {
	Window parent; /// What window this widget is in
	int x;         /// Position X of this widget
	int y;         /// Position Y of this widget
	string id;     /// ID of this widget

	this(Window parent, int x, int y, string id) {
		this.parent = parent;
		this.x = x;
		this.y = y;
	}

	void draw(bool active) {}                /// What to do when drawn
	bool click(int x, int y, MouseButton b) {return false;} /// Called when clicked. Position is relative to the widget position. Returns whether or not this widget should be active
	void type(dchar ch) {}                   /// What to do when a character is typed and this widget is active
	/// Equivalent to `x+parent.x`
	@property int absX() { return x+parent.x; }
	/// Equivalent to `y+parent.y`
	@property int absY() { return y+parent.y; }
}

class Checkbox : Widget {
	enum SIZE        = 16;
	enum COLOR       = Color3f(.75, .75, .75);
	enum CHECK_COLOR = Color3f(1, 0, 0);
	
	string label;               /// Label to appear alongside this checkbox
	bool on;                    /// Whether this checkbox is on or off
	void delegate() onEnable;   /// What to do when this checkbox is enabled
	void delegate() onDisable;  /// What to do when this checkbox is disabled
	
	/// Default constructor. Initializes the ID to the label
	this(Window parent, int x, int y, string label, void delegate() onEnable = null, void delegate() onDisable = null) {
		super(parent, x, y, label);
		this.label = label;
		this.onEnable = onEnable;
		this.onDisable = onDisable;
	}
	
	/// Construct with a bool pointer. A `onEnable` and `onDisable` is constructed to automatically align the value at the pointer with the
	/// value of `on`. `invert` may be specified to set the value at the pointer to the opposite of `on`.
	this(Window parent, int x, int y, string label, bool* ptr, bool invert = false) {
		super(parent, x, y, label);
		this.label = label;
		onEnable = () {
			*ptr = !invert;
		};
		onDisable = () {
			*ptr = invert;
		};
		*ptr = invert;
	}

	override void draw(bool active) {
		this.render(active);
	}
	override bool click(int x, int y, MouseButton b) {
		if(b != MouseButton.left || x < 0 || x > SIZE || y < 0 || y > SIZE)
			return false;	
		on = !on;
		if(on) {
			if(onEnable)
				onEnable();
		} else if(onDisable)
			onDisable();
		return false;
	}
}

/// A single button
class Button : Widget {
	string label;
	void delegate() onClick;
	int width;
	int height;

	enum COLOR = Color3f(.75, .75, .75);

	this(Window parent, int x, int y, int width, int height, string label, void delegate() onClick) {
		super(parent, x, y, label);
		this.width = width;
		this.height = height;
		this.label = label;
		this.onClick = onClick;
	}

	override void draw(bool active) {
		this.render(active);
	}

	override bool click(int x, int y, MouseButton b) {
		if(b != MouseButton.left || x < 0 || y < 0 || x > width || y > height)
			return false;
		onClick();
		return true;
	}
}

class Window {
	Widget[] widgets;    /// Widgets in this window
	string title;        /// Title of this window
	int width;           /// Width of this window
	int height;          /// Height of this window
	int x;               /// X position of this window
	int y;               /// Y position of this window
	Widget activeWidget; /// Currently active widget
	bool visible = true; /// Whether this window is visible or not

	enum TEXT_COLOR  = Color3f(1,   1,   1);   /// Color of window text
	enum TITLE_COLOR = Color3f(.25, .25, .25); /// Color of window title bar
	enum BODY_COLOR  = Color3f(.5,  .5,  .5);  /// Color of the body of windows

	enum TITLE_HEIGHT = 24; /// Height of the window title bar

	this(int x, int y, int width, int height, string title) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
		this.title = title;
	}
	
	/// Called when this window is clicked. X and Y should be relative to the window's position
	bool click(int cx, int cy, MouseButton button) {
		import std.stdio;
		if(cx < 0 || cx > width || cy < 0 || cy > height)
			return false;
		foreach(w; widgets)
			w.click(cx-w.x, cy-w.y, button);
				// activeWidget = w;
		return true;
	}

	/// Called when a character is pressed and this is the active window
	void type(dchar ch) {
		if(activeWidget !is null)
			activeWidget.type(ch);
	}

	/// Adds a widget to the window. Returns the window.
	Window addWidget(Widget w) {
		widgets ~= w;
		return this;
	}

	/// Whether a given point is inside this window's title bar
	bool inTitleBar(int a, int b) {
		return a >= x && a <= x+width && b >= y-TITLE_HEIGHT && b <= y;
	}
}

Window[] windows;
