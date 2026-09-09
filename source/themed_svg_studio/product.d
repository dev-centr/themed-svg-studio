/// Product identity and support surfaces.
module themed_svg_studio.product;

import std.array : appender;
import std.algorithm.searching : canFind;
import std.datetime.systime : Clock;
import std.format : formattedWrite;
import std.process : environment;
import std.string : strip;

version (Windows)
    enum osName = "Windows";
else version (linux)
    enum osName = "Linux";
else version (OSX)
    enum osName = "macOS";
else
    enum osName = "unknown";

enum productName = "Themed SVG Studio";
enum productVersion = import("VERSION").strip;
enum productChannel = "development";

version (ThemedSvgStudioBuildId)
    enum buildId = ThemedSvgStudioBuildId;
else
    enum buildId = "local";

string aboutText()
{
    return productName ~ " " ~ productVersion ~ "\nBuild: " ~ buildId
        ~ "\nChannel: " ~ productChannel ~ "\nLicense: MIT";
}

string helpText()
{
    return "Edit semantic SVG tokens, presets, and explicit bindings.\n"
        ~ "This product does not edit paths or other geometry.\n\n"
        ~ "Documentation: https://docs.devcentr.org/themed-svg-studio/\n"
        ~ "Issues: https://github.com/dev-centr/themed-svg-studio/issues";
}

string updateStatus()
{
    return "Automatic updates are not configured in v0.1.0. "
        ~ "Check signed release artifacts at https://github.com/dev-centr/themed-svg-studio/releases.";
}

string debugDump(string documentPath = "", string bridgeCommand = "themed-svg-stdio")
{
    auto output = appender!string;
    output.formattedWrite("%s\nGenerated: %s\nOS: %s\nBridge: %s\n", aboutText,
            Clock.currTime.toISOExtString, osName, bridgeCommand);
    if (documentPath.length)
        output.formattedWrite("Document: %s\n", redactHome(documentPath));
    output ~= "TGC: enabled by build configuration\n";
    return output.data;
}

private string redactHome(string value)
{
    auto home = environment.get("USERPROFILE", environment.get("HOME", ""));
    if (home.length && value.length >= home.length && value[0 .. home.length] == home)
        return "~" ~ value[home.length .. $];
    return value;
}

unittest
{
    assert(aboutText.canFind(productName));
    assert(debugDump.canFind("TGC: enabled"));
}
