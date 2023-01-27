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
	void render(float x, float y, float scale = 1, Color3f col = Color3f(1, 1, 1), bool drawOutline = false) {
		glBegin(GL_QUADS);
		if(drawOutline) {
			glColor3f(0, 0, 0);
			for(int i = 0; i < CHAR_SIZE; i++) {
				for(int j = 0; j < CHAR_SIZE; j++) {
					if(!pixels[i][j])
						continue;
					enum OUTLINE_SIZE = 1;
					glVertex2f(x+i*scale-OUTLINE_SIZE,       y+j*scale-OUTLINE_SIZE      );
					glVertex2f(x+i*scale+scale+OUTLINE_SIZE, y+j*scale                   );
					glVertex2f(x+i*scale+scale+OUTLINE_SIZE, y+j*scale+scale+OUTLINE_SIZE);
					glVertex2f(x+i*scale-OUTLINE_SIZE,       y+j*scale+scale+OUTLINE_SIZE);
				}
			}
		}
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

void loadCharmap() {
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
void text(string s, float x, float y, float scale = 1, Color3f col = Color3f(0, 0, 0), bool drawOutline = false) {
	string colorCode;
	bool getColorCode;
	bool doOutline = false;
	float orgx = x;
	foreach(i, dchar c; s) {
		switch(c) {
			case '`':
				getColorCode = true;
				colorCode = "";
				break;
			case '\n':
				x = orgx;
				y += CHAR_SIZE*scale;
				break;
			case 'o':
				if(getColorCode) {
					getColorCode = false;
					doOutline = !doOutline;
					break;
				}
				goto default;
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
				ch.render(x, y, scale, col, drawOutline != doOutline);
				x += scale*ch.fontSpacing;
		}
	}
}
/// Renders a string center-aligned
void textCenter(string s, float x, float y, float scale = 1, Color3f col = Color3f(0, 0, 0), bool drawOutline = false) {
	text(s, x-(textLen(s, scale)/2), y, scale, col, drawOutline);
}

/// Length of text in pixels
float textLen(string s, float scale = 1) {
	float len = 0;
	foreach(dchar c; s)
		len += characters[c].fontSpacing*scale;
	return len;
}

/// Draws a rectangle at the given position
void rect(float x, float y, float w, float h, int mode = GL_QUADS) {
	glBegin(mode);
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
	alias TITLE_HEIGHT = Window.TITLE_HEIGHT;
	Window.TITLE_COLOR.draw;
	rect(w.x, w.y-TITLE_HEIGHT, w.width, Window.TITLE_HEIGHT);
	Window.BODY_COLOR.draw;
	rect(w.x, w.y, w.width, w.height);
	glColor3f(0, 0, 0);
	rect(w.x, w.y-TITLE_HEIGHT, w.width, w.height+TITLE_HEIGHT, GL_LINE_LOOP);
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
	textCenter(b.useLocalization ? localization[b.label] : b.label, b.absX+(b.width/2), b.absY);
}

/// Renders an action box
void render(ActionBox b, bool active) {
	auto parent = b.parent;
	auto actions = player.actions;
	foreach(i, a; actions) {
		string t = "unknown action";
		if(auto ma = cast(MovementAction)a)
			// Move: n, A -> B
			t = localization["move"]~": "~ma.amt.to!string~", `"~Color3f(ma.source.color).toHexString~localization[ma.source.name]
				~"`FFFFFF -> `"~Color3f(ma.dest.color).toHexString~localization[ma.dest.name];
		else if(auto da = cast(DeploymentAction)a)
			// Deploy: n, A
			t = localization["deploy"]~": "~da.amt.to!string~", `"~Color3f(da.province.color).toHexString~localization[da.province.name];
		text(t, parent.x+ActionBox.SPACING, parent.y+ActionBox.SPACING+i*CHAR_SIZE, 1, Color3f(1, 1, 1));
	}
}

/// Renders a count button
void render(CountButton b, bool active) {
	auto parent = b.parent;
	CountButton.COLOR.draw;
	alias COUNT_SIZE = CountButton.COUNT_SIZE;
	rect(b.absX+COUNT_SIZE*b.width, b.absY, b.width-COUNT_SIZE*b.width, b.height);
	textCenter(localization[b.label], b.absX+(COUNT_SIZE*b.width)/2+b.width/2, b.absY);
	CountButton.COUNT_COLOR.draw;
	rect(b.absX, b.absY, b.width*COUNT_SIZE, b.height);
	textCenter(b.count.to!string~(b.max == int.max ? "" : "/"~b.max.to!string), b.absX+(b.width*COUNT_SIZE)/2, b.absY, 1, Color3f(1, 1, 1));
}

/// Renders a text widget
void render(Text t, bool active) {
	auto parent = t.parent;
	text(t.text, t.absX, t.absY, 1, Color3f(1, 1, 1));
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
	textCenter(localization[c.name], avg.x, avg.y, 1+((count-1)/3), Color3f(1, 1, 1), true);
}

/// Renders a province's text (must be called after all provinces are rendered to avoid the text being clobbered)
void renderText(Province p) {
	textCenter(localization[p.name], p.center.x, p.center.y, 1, Color3f(1, 1, 1), true);
	string troopsText = p.troops.to!string;
	int effective = p.effectiveTroops;
	if(p.effectiveTroops != p.troops) {
		int dif = effective-p.troops;
		troopsText ~= " ("~(dif > 0 ? "+" : "")~dif.to!string~")";
	}
	textCenter(troopsText, p.center.x, p.center.y+CHAR_SIZE, 1, Color3f(1, 1, 1), true);
}

bool hideStraits; /// Whether or not to hide straits

/// Redraws the opengl scene
void redrawOpenGlScene() {
	glLoadIdentity();
	glOrtho(0, WIDTH, HEIGHT, 0, -1, 1);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
	glBegin(GL_QUADS);
	// draw game background
	float bgMultiplier = 1;
	if(state == State.GAME && [MapMode.SELECT_COUNTRY, MapMode.MOVE_TROOPS_1, MapMode.MOVE_TROOPS_2, MapMode.DEPLOY_TROOPS, MapMode.WON, MapMode.LOST].canFind(mapMode))
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
		foreach_reverse(i, w; windows) {
			w.render();
			if(w.close)
				windows = windows[0..i]~windows[i+1..$];
		}
	}
	void renderStraits() {
		glBegin(GL_LINES);
		glColor3f(1, 0, 1);
		foreach(strait; straits) {
			auto a = strait[0];
			auto b = strait[1];
			glVertex2f(a.x, a.y);
			glVertex2f(b.x, b.y);
		}
		glEnd();
	}
	if(state == State.GAME) {
		switch(mapMode) {
			case MapMode.SELECT_COUNTRY:
				renderCountries();
				textCenter(localization["select-country"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				break;
			case MapMode.COUNTRY:
				if(!hideStraits)
					renderStraits();
				renderCountries();
				renderWindows();
				break;
			case MapMode.PROVINCE:
				if(!hideStraits)
					renderStraits();
				renderProvinces();
				renderWindows();
				break;
			case MapMode.MOVE_TROOPS_1:
				renderStraits();
				renderProvinces(0.5);
				renderProvinces(1, availableProvinces);
				textCenter(localization["select-source-province"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["or-press-escape"], WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));
				break;
			case MapMode.MOVE_TROOPS_2:
				renderStraits();
				renderProvinces(0.5);
				renderProvinces(1, availableProvinces);
				textCenter(localization["select-destination-province"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["or-press-escape"], WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));
				break;
			case MapMode.DEPLOY_TROOPS:
				renderStraits();
				renderProvinces(0.5);
				renderProvinces(1, availableProvinces);
				textCenter(localization["select-province-to-deploy"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["or-press-escape"], WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));
				break;
			case MapMode.WON:
				renderCountries();
				textCenter(localization["won"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["in-turns"].format(currentTurn), WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));
				break;
			case MapMode.LOST:
				renderCountries();
				textCenter(localization["lost"], WIDTH/2, 0, 3, Color3f(1, 1, 1));
				textCenter(localization["in-turns"].format(currentTurn), WIDTH/2, CHAR_SIZE*3, 1, Color3f(1, 1, 1));	
				break;
			default:
				break;
		}
		return;
	}
	renderWindows();
}
