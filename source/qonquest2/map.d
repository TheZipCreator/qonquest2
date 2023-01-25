/// Contains code handling the map
module qonquest2.map;

import std.json, std.file, std.typecons;
import qonquest2.display : Color3f;

import arsd.png;
import arsd.simpledisplay : Point, Color;

private int brightness(Color c) {
	return (c.r + c.g + c.b)/3;
}

private enum COLOR_SWAP_THRESHOLD = 128; /// Which brightness to start putting the inverse color instead of the light color
private enum LIGHT_TEXT_COLOR = Color3f(1, 1, 1); /// Light text color

/// Represents a country
class Country {
	string name; /// Name of this country
	Color color; /// Color of this country
	int deployableTroops = 2; /// Number of troops can currently be deployed

	this(string name, Color color) {
		this.name = name;
		this.color = color;
	}

	Province[] ownedProvinces() {
		Province[] ret;
		foreach(p; provinces)
			if(p.owner is this)
				ret ~= p;
		return ret;
	}

	string hexCode() {
		return "`"~Color3f(color).toHexString;
	}

	@property Color3f textColor() {
		return color.brightness() > COLOR_SWAP_THRESHOLD ? Color3f(color).inverse : LIGHT_TEXT_COLOR;
	}
}

/// Represents a province
class Province {
	Country owner;        /// Owner of this province
	Point[] pixels;       /// Pixels of this province
	Color color;          /// Color of this province
	string name;          /// Name of this province
	Point center;         /// Center of this province
	Province[] neighbors; /// Neighbors of this province
	int troops;           /// How many troops are in this province

	this(string name, Color col, Point center, Country owner) {
		this.name  = name;
		this.color = col;
		this.center = center;
		this.owner = owner;
	}

	override string toString() {
		return name;
	}

	string hexCode() {
		return "`"~Color3f(color).toHexString;
	}

	@property Color3f textColor() {
		return color.brightness() > COLOR_SWAP_THRESHOLD ? Color3f(color).inverse : LIGHT_TEXT_COLOR;
	}
}

Country[string] countries; /// All countries in the game
Province[]      provinces; /// All provinces in the game

/// Converts a jsonvalue into a Color
private Color toColor(JSONValue v) {
	auto arr = v.array;
	return Color(cast(ubyte)(arr[0].integer), cast(ubyte)(arr[1].integer), cast(ubyte)(arr[2].integer));
}

/// Converts a JSONValue into a Point
private Point toPoint(JSONValue v) {
	auto arr = v.array;
	return Point(cast(ushort)(arr[0].integer), cast(ushort)(arr[1].integer));
}

class MapLoadException : Exception {
	this(string msg) {
		super(msg);
	}
}

Tuple!(Point, Point)[] straits;

/// Loads the map (including countries & provinces)
void loadMap() {
	countries.clear();
	provinces = [];
	auto mapJSON  = parseJSON(readText("data/map.json"));
	// load countries
	foreach(country; mapJSON["countries"].array) {
		string name = country["name"].str;
		if(name in countries)
			throw new MapLoadException("Duplicate country "~name~".");
		auto col = country["color"].toColor();
		countries[name] = new Country(name, col);
	}
	// load provinces
	Province[Color] provinceColors; // temporary lookup table to make processing map more efficient
	foreach(province; mapJSON["provinces"].array) {
		auto col = province["color"].toColor();
		if(col in provinceColors)
			throw new MapLoadException("Duplicate province with color "~province["color"].toString~".");
		auto owner = province["owner"].str;
		string name = province["name"].str;
		if("gen-country" in province && province["gen-country"].boolean)
			countries[name] = new Country(name, col);
		if(owner !in countries)
			throw new MapLoadException("Unknown country "~owner~".");
		auto prov = new Province(name, col, province["center"].toPoint, countries[owner]);
		if("neighbors" in province)
			foreach(i_; province["neighbors"].array) {
				string i = i_.str;
				import std.algorithm;
				Province other = provinces.find!(c => c.name == i)[0];
				prov.neighbors ~= other;
				other.neighbors ~= prov;
				straits ~= tuple(prov.center, other.center);
			}
		provinces ~= prov;
		provinceColors[col] = prov;
	}
	auto mapImage = readPng("data/map.png");
	// loop through image
	for(int i = 0; i < mapImage.width; i++) {
		for(int j = 0; j < mapImage.height; j++) {
			// if this pixel belongs to a province, add it
			Color c = mapImage.getPixel(i, j);
			if(c !in provinceColors)
				continue;
			auto p = provinceColors[c];
			p.pixels ~= Point(i, j);
			// add neighbors
			if(i == 0 || j == 0)
				continue;
			foreach(col; [mapImage.getPixel(i-1, j), mapImage.getPixel(i, j-1), mapImage.getPixel(i-1, j-1)]) {
				if(col !in provinceColors || col == c)
					continue;
				auto other = provinceColors[col];
				import std.algorithm : canFind;
				if(p.neighbors.canFind(other))
					continue;
				p.neighbors ~= other;
				other.neighbors ~= p;
			}
		}
	}
}
