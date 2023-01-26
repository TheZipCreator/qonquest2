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
}
