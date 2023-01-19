/// Contains all code for displaying things to the screen
module qonquest2.display;

import std.file, std.conv, std.format, std.algorithm, std.range;
import arsd.simpledisplay, arsd.png;

import qonquest2.app, qonquest2.map, qonquest2.window, qonquest2.localization, qonquest2.logic;
import qonquest2.window : Window;

enum WIDTH  = 1200; /// width of the window
enum HEIGHT = 800; /// height of the window

enum CHAR_SIZE = 16; /// character size

/// A color with 3 floats
struct Color3f {
	float r; /// Red
	float g; /// Green
	float b; /// Blue
	/// Create from components
	this(float r, float g, float b) {
		this.r = r;
		this.g = g;
		this.b = b;
	}
	/// Create from arsd.color.Color
	this(Color c) {
		this.r = c.r/256f;
		this.g = c.g/256f;
		this.b = c.b/256f;
	}
	/// Create from a hex string
	this(string hex) {
		if(hex.length != 6)
			return;
		try {
			r = (hex[0..2].to!int(16))/256f;
			g = (hex[2..4].to!int(16))/256f;
			b = (hex[4..6].to!int(16))/256f;
		} catch(ConvException) {}
	}

	/// Runs glColor3f on this color
	void draw() {
		glColor3f(r, g, b);
	}
	/// Returns the inverse of this color
	Color3f inverse() {
		return Color3f(1-r, 1-g, 1-b);
	}
	/// Multiplies colors by a given amount
	Color3f mul(float n) {
		return Color3f(r*n, g*n, b*n);
	}

	/// Converts this color to a hex string
	string toHexString() {
		return format("%02x%02x%02x", cast(int)(r*256), cast(int)(g*256), cast(int)(b*256));
	}
}

/// A point with two floats
struct Point2f {
	float x = 0;
	float y = 0;
	this(float x, float y) {
		this.x = x;
		this.y = y;
	}
	/// Construct from a point
	this(Point p) {
		x = p.x;
		y = p.y;
	}

	void opOpAssign(string op = "+")(Point2f other) {
		x += other.x;
		y += other.y;
	}

	void opOpAssign(string op = "/")(float amt) {
		x /= amt;
		y /= amt;
	}
}

/// A single character in the font
struct Char {
	bool[CHAR_SIZE][CHAR_SIZE] pixels; /// Pixels of this character
	int fontSpacing = CHAR_SIZE; /// Width of this character (used in `text()`)
	/// Renders this character at the given position (must be called within redrawOpenGlScene)
	void render(float x, float y, float scale = 1, Color3f col = Color3f(1, 1, 1)) {
		glBegin(GL_QUADS);
		col.draw;
		for(int i = 0; i < CHAR_SIZE; i++) {
			for(int j = 0; j < CHAR_SIZE; j++) {
				if(!pixels[i][j])
					continue;
				glVertex2f(x+i*scale,       y+j*scale      );
				glVertex2f(x+i*scale+scale, y+j*scale      );
				glVertex2f(x+i*scale+scale, y+j*scale+scale);
				glVertex2f(x+i*scale,       y+j*scale+scale);
			}
		}
		glEnd();
	}
}

Char[] characters; /// Characters in the font

static this() {
	// load font
	auto fontImage = readPng("data/font.png");
	import std.algorithm, std.array, std.string, std.conv;
	int[] fontSpacing = readText("data/font-spacing.txt")[0..$-1].splitLines.map!(x => x.to!int).array;
	for(int i = 0; i < fontImage.width/CHAR_SIZE; i++) {
		for(int j = 0; j < fontImage.height/CHAR_SIZE; j++) {
			int x = j*CHAR_SIZE;
			int y = i*CHAR_SIZE;
			Char c;
			// there's probably a better way to do this than four nested for loops
			for(int k = 0; k < CHAR_SIZE; k++) {
				for(int l = 0; l < CHAR_SIZE; l++) {
					c.pixels[k][l] = fontImage.getPixel(x+k, y+l).r == 0;
				}
			}
			if(characters.length < fontSpacing.length)
				c.fontSpacing = fontSpacing[characters.length];
			characters ~= c;
		}
	}
}

/// Renders a string at the given position
void text(string s, float x, float y, float scale = 1, Color3f col = Color3f(0, 0, 0)) {
	string colorCode;
	bool getColorCode;
	foreach(i, dchar c; s) {
		switch(c) {
			case '`':
				getColorCode = true;
				colorCode = "";
				break;
			default:
				if(getColorCode) {
					colorCode ~= c;
					if(colorCode.length != 6)
						break;
					getColorCode = false;
					col = Color3f(colorCode);
					break;
				}
				auto ch = characters[c];
				ch.render(x, y, scale, col);
				x += scale*ch.fontSpacing;
		}
	}
}
/// Renders a string center-aligned
void textCenter(string s, float x, float y, float scale = 1, Color3f col = Color3f(0, 0, 0)) {
	text(s, x-(textLen(s, scale)/2), y, scale, col);
}

/// Length of text in pixels
float textLen(string s, float scale = 1) {
	float len = 0;
	foreach(dchar c; s)
		len += characters[c].fontSpacing*scale;
	return len;
}

/// Draws a rectangle at the given position
void rect(float x, float y, float w, float h) {
	glBegin(GL_QUADS);
	glVertex2f(x,   y  );
	glVertex2f(x+w, y  );
	glVertex2f(x+w, y+h);
	glVertex2f(x,   y+h);
	glEnd();
}

/// Draws a window
void render(Window w) {
	if(!w.visible)
		return;
	Window.TITLE_COLOR.draw;
	rect(w.x, w.y-Window.TITLE_HEIGHT, w.width, Window.TITLE_HEIGHT);
	Window.BODY_COLOR.draw;
	rect(w.x, w.y, w.width, w.height);
	text(localization[w.title], w.x+8, w.y-Window.TITLE_HEIGHT+4, 1, Window.TEXT_COLOR);
	foreach(wi; w.widgets)
		wi.draw(wi is w.activeWidget);
}

/// Draws a checkbox
void render(Checkbox c, bool active) {
	auto parent = c.parent;
	Checkbox.COLOR.draw;
	rect(c.absX, c.absY, Checkbox.SIZE, Checkbox.SIZE);
	if(c.on) {
		Checkbox.CHECK_COLOR.draw;
		rect(c.absX+Checkbox.SIZE/4, c.absY+Checkbox.SIZE/4, Checkbox.SIZE/2, Checkbox.SIZE/2);
	}
	text(localization[c.label], c.absX+Checkbox.SIZE, c.absY, 1, Color3f(1, 1, 1));
}
/// Renders a button
void render(Button b, bool active) {
	auto parent = b.parent;
	Button.COLOR.draw;
	rect(b.absX, b.absY, b.width, b.height);
	textCenter(localization[b.label], b.absX+(b.width/2), b.absY);
}
/// Renders an action box
void render(ActionBox b, bool active) {
	auto parent = b.parent;
	auto actions = players[currentPlayer].actions;
	foreach(i, a; actions) {
		string t = "unknown action";
		if(auto ma = cast(MovementAction)a)
			// Move: A -> B
			t = localization["move"]~": `"~Color3f(ma.source.color).toHexString~localization[ma.source.name]
				~"`FFFFFF -> `"~Color3f(ma.dest.color).toHexString~localization[ma.dest.name];
		else if(auto da = cast(DeploymentAction)a)
			// Deploy: n to A
			t = localization["deploy"]~": "~da.amt.to!string~" to `"~Color3f(da.province.color).toHexString~localization[da.province.name];
		text(t, parent.x+ActionBox.SPACING, parent.y+ActionBox.SPACING+i*CHAR_SIZE, 1, Color3f(1, 1, 1));
		glColor3f(.5, 0, 0);
		float x = parent.x+parent.width-ActionBox.SPACING-ActionBox.X_SIZE;
		float y = parent.y+ActionBox.SPACING+i*CHAR_SIZE; 
		rect(x, y, ActionBox.X_SIZE, ActionBox.X_SIZE);
		glColor3f(1, 0, 0);
		glBegin(GL_LINES);
		glVertex2f(x+1, y+1);
		glVertex2f(x+ActionBox.X_SIZE, y+ActionBox.X_SIZE);
		glVertex2f(x+ActionBox.X_SIZE, y+1);
		glVertex2f(x+1, y+ActionBox.X_SIZE);
		glEnd();
	}
}

/// Renders a province
void render(Province p, float multiplier = 1) {
	Color3f(p.color).mul(multiplier).draw;
	glBegin(GL_QUADS);
	foreach(pix; p.pixels) {
		glVertex2f(pix.x,   pix.y  );
		glVertex2f(pix.x+1, pix.y  );
		glVertex2f(pix.x+1, pix.y+1);
		glVertex2f(pix.x,   pix.y+1);
	}
	glEnd();
}

/// Renders a province's country
void renderCountry(Province p, float multiplier = 1) {
	Color3f(p.owner.color).mul(multiplier).draw;
	glBegin(GL_QUADS);
	foreach(pix; p.pixels) {
		glVertex2f(pix.x,   pix.y  );
		glVertex2f(pix.x+1, pix.y  );
		glVertex2f(pix.x+1, pix.y+1);
		glVertex2f(pix.x,   pix.y+1);
	}
	glEnd();
}

/// Renders the text for a country
void renderText(Country c) {
	Point2f avg;
	int count = 0;
	foreach(p; provinces) {
		if(p.owner !is c)
			continue;
		count++;
		avg += Point2f(p.center);
	}
	avg /= count;
	textCenter(localization[c.name], avg.x, avg.y, 1+((count-1)/2), Color3f(c.color).inverse);
}

/// Renders a province's text (must be called after all provinces are rendered to avoid the text being clobbered)
void renderText(Province p) {
	textCenter(localization[p.name], p.center.x, p.center.y, 1, Color3f(p.color).inverse);
	textCenter(p.troops.to!string, p.center.x, p.center.y+CHAR_SIZE, 1, Color3f(p.color).inverse.mul(.5));
}

/// Redraws the opengl scene
void redrawOpenGlScene() {
	glLoadIdentity();
	glOrtho(0, WIDTH, HEIGHT, 0, -1, 1);
	glBegin(GL_QUADS);
	// draw game background
	float bgMultiplier = 1;
	if([MapMode.SELECT_COUNTRY, MapMode.MOVE_TROOPS_1, MapMode.MOVE_TROOPS_2].canFind(mapMode))
		bgMultiplier = 0.5;
	glColor3f(0, 0, 1*bgMultiplier);
	glVertex2f(0, 0);
	glVertex2f(WIDTH, 0);
	glColor3f(0, 0.75*bgMultiplier, 1*bgMultiplier);
	glVertex2f(WIDTH, HEIGHT);
	glVertex2f(0, HEIGHT);
	glEnd();
	void renderCountries(float m = 1) {
		foreach(p; provinces)
			p.renderCountry(m);
		foreach(c; countries)
			c.renderText();
	}
	void renderProvinces(float m = 1, Province[] provs = provinces) {
		foreach(p; provs)
			p.render(m);
		foreach(p; provs)
			p.renderText();
	}
	void renderWindows() {
		foreach(w; windows)
			w.render();
	}
	if(state == State.GAME) {
		switch(mapMode) {
			case MapMode.SELECT_COUNTRY:
				renderCountries();
				textCenter(localization["select-country"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				break;
			case MapMode.COUNTRY:
				renderCountries();
				renderWindows();
				break;
			case MapMode.PROVINCE:
				renderProvinces();
				renderWindows();
				break;
			case MapMode.MOVE_TROOPS_1:
				renderProvinces(0.5);
				renderProvinces(1, provinces.filter!(p => canMoveTroopsFrom(p)).array);
				textCenter(localization["select-source-province"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["or-press-escape"], WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));
				break;
			case MapMode.MOVE_TROOPS_2:
				renderProvinces(0.5);
				renderProvinces(1, provinces.filter!(p => canMoveTroopsTo(selectedProvince, p)).array);
				textCenter(localization["select-destination-province"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["or-press-escape"], WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));
				break;
			default:
				break;
		}
		return;
	}
	renderWindows();
}
