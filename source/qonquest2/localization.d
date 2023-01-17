/// Contains code handling localization
module qonquest2.localization;

import std.file, std.json;

private struct Localization {
	string[string] keys;
	
	string opIndex(string key) {
		return key in keys ? keys[key] : key;
	}
}

Localization localization;

void loadLocalization(string language) {
	localization = Localization();
	string path = "data/localization/"~language~".json";
	if(!path.exists || !path.isFile)
		return; // TODO: report error
	auto json = path.readText.parseJSON;
	foreach(string k, v; json) {
		localization.keys[k] = v.str;
	}
}
