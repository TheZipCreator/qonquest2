/// Contains code handling localization
module qonquest2.localization;

import std.file, std.json;

import qonquest2.app : howToPlayWindow;
import qonquest2.window : Text;
import qonquest2.display : CHAR_SIZE;

private struct Localization {
	string[string] keys;
	
	string opIndex(string key) {
		return key in keys ? keys[key] : key;
	}
}

Localization localization; /// The struct containing all localizations
string[string] languages;  /// List of languages (ISO 639-3 code -> Language name)

static this() {
	foreach(string k, v; "data/localization/language-names.json".readText.parseJSON)
		languages[k] = v.str;
}

void loadLocalization(string language) {
	localization.keys.clear();
	string path = "data/localization/"~language~".json";
	if(!path.exists || !path.isFile)
		return; // TODO: report error
	auto json = path.readText.parseJSON;
	foreach(string k, v; json) {
		switch(v.type) {
			case JSONType.string:
				localization.keys[k] = v.str;
				break;
			case JSONType.object:
				final switch(v["type"].str) {
					case "file":
						localization.keys[k] = readText(v["location"].str);
						break;
				}
				break;
			default:
				throw new Exception("Invalid value type");
		}
	}
	(cast(Text)howToPlayWindow.widgets[0]).text = localization["how-to-play-file"];
	import std.string : splitLines;
	howToPlayWindow.height = cast(int)(localization["how-to-play-file"].splitLines.length)*CHAR_SIZE;
}
