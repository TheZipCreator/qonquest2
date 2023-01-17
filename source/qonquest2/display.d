module qonquest2.display;

import std.file, std.conv;
import arsd.simpledisplay, arsd.png;

import qonquest2.app, qonquest2.map, qonquest2.window, qonquest2.localization;
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
		this.r = c.r/255f;
		this.g = c.g/255f;
		this.b = c.b/255f;
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
	foreach(dchar c; s) {
		auto ch = characters[c];
		ch.render(x, y, scale, col);
		x += scale*ch.fontSpacing;
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
		len += characters[c].fontSpacing;
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

/// Redraws the opengl scene
void redrawOpenGlScene() {
	glLoadIdentity();
	glOrtho(0, WIDTH, HEIGHT, 0, -1, 1);
	glBegin(GL_QUADS);
	// draw game background
	glColor3f(0, 0, 1);
	glVertex2f(0, 0);
	glVertex2f(WIDTH, 0);
	glColor3f(0, 0.75, 1);
	glVertex2f(WIDTH, HEIGHT);
	glVertex2f(0, HEIGHT);
	// draw provinces
	foreach(p; provinces) {
		auto col = p.color;
		Color3f(col).draw;
		foreach(pix; p.pixels) {
			glVertex2f(pix.x,   pix.y  );
			glVertex2f(pix.x+1, pix.y  );
			glVertex2f(pix.x+1, pix.y+1);
			glVertex2f(pix.x,   pix.y+1);
		}
	}
	glEnd();
	// draw province names & troop counts
	foreach(p; provinces) {
		textCenter(localization[p.name], p.center.x, p.center.y, 1, Color3f(p.color).inverse);
		textCenter(p.troops.to!string, p.center.x, p.center.y+CHAR_SIZE, 1, Color3f(p.color).inverse.mul(.5));
	}
	foreach(w; windows)
		w.render();
}
