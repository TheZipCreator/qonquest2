/// Contains code handling windows and widgets
module qonquest2.window;

import qonquest2.display, qonquest2.app;
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
		this.id = id;
	}

	void draw(bool active) {}                /// What to do when drawn
	bool click(int x, int y, MouseButton b) {return false;} /// Called when clicked. Position is relative to the widget position. Returns whether or not this widget should be active
	void type(dchar ch) {}                   /// What to do when a character is typed and this widget is active
	/// Equivalent to `x+parent.x`
	@property int absX() { return x+parent.x; }
	/// Equivalent to `y+parent.y`
	@property int absY() { return y+parent.y; }
}

/// A simple checkbox
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

/// A simple button
final class Button : Widget {
	string label;
	void delegate() onClick;
	int width;
	int height;
	bool useLocalization = true;

	enum COLOR = Color3f(.75, .75, .75);

	this(Window parent, int x, int y, int width, int height, string label, void delegate() onClick) {
		super(parent, x, y, label);
		this.width = width;
		this.height = height;
		this.label = label;
		this.onClick = onClick;
	}

	this(Window parent, int x, int y, int width, int height, string label, bool useLocalization, void delegate() onClick) {
		this.useLocalization = useLocalization;
		this(parent, x, y, width, height, label, onClick);
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

/// A button with a counter
class CountButton : Widget {
	string label;
	void delegate(int) onClick;
	int width;
	int height;
	int count;
	int min;
	int max;

	enum COLOR = Color3f(.75, .75, .75);
	enum COUNT_COLOR = Color3f(.25, .25, .25);
	enum COUNT_SIZE = 0.25;

	this(Window parent, int x, int y, int width, int height, string label, int min, int max, void delegate(int) onClick) {
		super(parent, x, y, label);
		this.width = width;
		this.height = height;
		this.label = label;
		this.onClick = onClick;
		this.min = min;
		this.max = max;
	}

	override void draw(bool active) {
		this.render(active);
		checkBounds();
	}

	void checkBounds() {
		if(count < min)
			count = min;
		else if(count > max)
			count = max;
	}

	override bool click(int x, int y, MouseButton b) {
		int amt() {
			return shiftPressed ? 5 : 1;
		}
		scope(exit)
			checkBounds();
		if(b == MouseButton.left) {
			if(x < 0 || y < 0 || x > width || y > height)
				return false;
			if(x < width*COUNT_SIZE) {
				count += amt();
				return true;
			}
			onClick(count);
			return true;
		} else if(b == MouseButton.right) {
			if(x < 0 ||  y < 0 || x > width*COUNT_SIZE || y > height)
				return false;
			count -= amt();
			return true;
		}
		return false;
	}
}

/// A widget displaying all actions.
class ActionBox : Widget {
	this(Window parent) {
		super(parent, 0, 0, "action-box");
	}

	enum X_SIZE    = 14;
	enum SPACING   = 4;

	override void draw(bool active) {
		this.render(active);
	}

	override bool click(int x, int y, MouseButton b) {
		if(b != MouseButton.left || x < parent.width-X_SIZE-SPACING || x > parent.width-SPACING || y < SPACING)
			return false;
		
		return false;
	}
}

/// Static text
class Text : Widget {
	string text;

	this(Window parent, int x, int y, string text) {
		super(parent, x, y, text);
		this.text = text;
	}

	override void draw(bool active) {
		this.render(active);
	}
}

/// The main window class
class Window {
	Widget[] widgets;    /// Widgets in this window
	string title;        /// Title of this window
	int width;           /// Width of this window
	int height;          /// Height of this window
	int x;               /// X position of this window
	int y;               /// Y position of this window
	Widget activeWidget; /// Currently active widget
	bool visible = true; /// Whether this window is visible or not
	bool close = false;  /// Tells the program to close this window

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
	
	static int lastX = 100;
	static int lastY = 100;

	this(int width, int height, string title) {
		this.x = lastX;
		this.y = lastY;
		lastX += width/2;
		lastY += height/2;
		if(lastX+width > WIDTH)
			lastX = 100;
		if(lastY+height > HEIGHT)
			lastY = 100;
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

	/// Get a widget via its id
	Widget getWidget(string id) {
		foreach(w; widgets) 
			if(w.id == id)
				return w;
		return null;
	}
}

Window[] windows;
