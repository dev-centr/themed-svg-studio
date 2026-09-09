module themed_svg_studio.cli_main;

import tgc.gcobj;
import std.algorithm.searching : canFind;
import std.conv : to;
import std.exception : enforce;
import std.file : readText, write;
import std.getopt;
import std.json;
import std.stdio;
import themed_svg_studio;

int main(string[] args)
{
    string svgPath;
    string manifestPath;
    string output;
    string bridge;
    string preset;
    bool help;
    bool versionRequested;
    bool debugDumpRequested;

    auto options = getopt(args, "svg", &svgPath, "manifest|m", &manifestPath, "output|o",
            &output, "bridge", &bridge, "preset", &preset, "version",
            &versionRequested, "debug-dump", &debugDumpRequested, "help|h", &help);

    if (versionRequested)
    {
        writeln(aboutText);
        return 0;
    }
    if (debugDumpRequested)
    {
        writeln(debugDump(svgPath, bridge.length ? bridge : "themed-svg-stdio"));
        return 0;
    }
    if (help || args.length < 2)
    {
        showHelp;
        return help ? 0 : 1;
    }

    const command = args[1];
    try
    {
        if (command == "smoke")
            return smoke;
        if (command == "help")
        {
            showHelp;
            return 0;
        }
        auto operation = parseOperation(command);
        enforce(svgPath.length, "--svg is required.");
        ProtocolRequest request;
        request.id = "cli-1";
        request.operation = operation;
        request.svg = readText(svgPath);
        if (manifestPath.length)
            request.manifest = parseManifest(readText(manifestPath));
        request.options.preset = preset;

        auto adapter = bridge.length
            ? new JsonlProcessAdapter([bridge])
            : new JsonlProcessAdapter;
        auto response = adapter.call(request);
        foreach (diagnostic; response.diagnostics)
            stderr.writefln("%s: %s: %s", cast(string) diagnostic.severity,
                    diagnostic.code, diagnostic.message);
        if (!response.ok)
        {
            stderr.writeln(response.error.length ? response.error : "Operation failed.");
            return 2;
        }
        const rendered = response.result.toPrettyString;
        if (output.length)
            write(output, rendered);
        else
            writeln(rendered);
        return response.diagnostics.canFind!(item => item.severity == Severity.error) ? 2 : 0;
    }
    catch (Exception error)
    {
        stderr.writeln("error: ", error.msg);
        return 1;
    }
}

private ProtocolOperation parseOperation(string value)
{
    switch (value)
    {
    case "inspect":
        return ProtocolOperation.inspect;
    case "validate":
        return ProtocolOperation.validate;
    case "transform":
        return ProtocolOperation.transform;
    case "sanitize":
        return ProtocolOperation.sanitize;
    case "export":
        return ProtocolOperation.exportArtifacts;
    default:
        throw new Exception("Unknown operation: " ~ value);
    }
}

private int smoke()
{
    ProtocolRequest request;
    request.id = "smoke";
    request.operation = ProtocolOperation.inspect;
    request.svg = `<svg viewBox="0 0 1 1"/>`;
    auto adapter = new RecordingAdapter;
    adapter.nextResponse = ProtocolResponse(1, "smoke", true);
    const response = adapter.call(request);
    enforce(response.ok && adapter.requests.length == 1, "CLI smoke failed.");
    writeln("themed-svg-studio smoke OK; protocol=", protocolVersion, "; tgc=enabled");
    return 0;
}

private void showHelp()
{
    writeln("Themed SVG Studio ", productVersion);
    writeln("Usage: themed-svg-studio-cli <inspect|validate|transform|sanitize|export> [options]");
    writeln("       themed-svg-studio-cli smoke");
    writeln("Options:");
    writeln("  --svg <file>         Source SVG");
    writeln("  -m, --manifest       Version 1 manifest");
    writeln("  -o, --output         JSON result path");
    writeln("  --bridge <command>   Protocol executable (default: themed-svg-stdio)");
    writeln("  --preset <name>      Active preset");
    writeln("  --debug-dump         Print a redacted support dump");
    writeln("  --version            Print product identity");
}
