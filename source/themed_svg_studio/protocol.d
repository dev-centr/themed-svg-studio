/// Stable protocol-v1 messages for the @dev-centr/themed-svg subprocess.
module themed_svg_studio.protocol;

import std.json;
import themed_svg_studio.diagnostics;
import themed_svg_studio.manifest;

enum protocolVersion = 1;

enum ProtocolOperation : string
{
    inspect = "inspect",
    validate = "validate",
    transform = "transform",
    sanitize = "sanitize",
    exportArtifacts = "export"
}

struct TransformOptions
{
    OutputMode mode = OutputMode.host;
    OutputMode[] modes;
    string preset;
    Palette palette;
    Palette lightPalette;
    Palette darkPalette;
}

struct ProtocolRequest
{
    int versionNumber = protocolVersion;
    string id;
    ProtocolOperation operation;
    string svg;
    Manifest manifest;
    TransformOptions options;
}

struct ProtocolResponse
{
    int versionNumber;
    string id;
    bool ok;
    JSONValue result;
    Diagnostic[] diagnostics;
    string error;
}

private JSONValue paletteJson(const Palette palette)
{
    JSONValue[string] values;
    foreach (key, value; palette)
        values[key] = value;
    return JSONValue(values);
}

JSONValue requestJson(const ProtocolRequest request)
{
    JSONValue[string] root;
    root["protocolVersion"] = request.versionNumber;
    root["id"] = request.id;
    root["operation"] = cast(string) request.operation;
    if (request.svg.length)
        root["svg"] = request.svg;
    if (
        request.manifest.namespace.length
        && request.operation != ProtocolOperation.inspect
        && request.operation != ProtocolOperation.sanitize
    )
        root["manifest"] = manifestJson(request.manifest);

    if (
        request.operation == ProtocolOperation.transform
        || request.operation == ProtocolOperation.exportArtifacts
    )
    {
        JSONValue[string] options;
        if (request.operation == ProtocolOperation.transform)
            options["mode"] = cast(string) request.options.mode;
        else if (request.options.modes.length)
        {
            JSONValue[] modes;
            foreach (mode; request.options.modes)
                modes ~= JSONValue(cast(string) mode);
            options["modes"] = modes;
        }
        if (request.options.preset.length)
            options["preset"] = request.options.preset;
        if (request.options.palette.length)
            options["palette"] = paletteJson(request.options.palette);
        if (request.options.lightPalette.length)
            options["lightPalette"] = paletteJson(request.options.lightPalette);
        if (request.options.darkPalette.length)
            options["darkPalette"] = paletteJson(request.options.darkPalette);
        if (options.length)
            root["options"] = options;
    }
    return JSONValue(root);
}

string encodeRequest(const ProtocolRequest request)
{
    return requestJson(request).toString(JSONOptions.doNotEscapeSlashes);
}

ProtocolResponse decodeResponse(string line)
{
    auto root = parseJSON(line);
    ProtocolResponse response;
    response.versionNumber = cast(int) root["protocolVersion"].integer;
    response.id = root["id"].str;
    if (auto ok = "ok" in root.object)
        response.ok = ok.type == JSONType.true_;
    if (auto result = "result" in root.object)
        response.result = *result;
    if (auto error = "error" in root.object)
        response.error = error.type == JSONType.string ? error.str : error.toString;
    if (auto diagnostics = "diagnostics" in root.object)
        foreach (item; diagnostics.array)
            response.diagnostics ~= diagnosticFromJson(item);
    return response;
}

unittest
{
    ProtocolRequest request;
    request.id = "test-1";
    request.operation = ProtocolOperation.inspect;
    request.svg = "<svg/>";
    auto json = parseJSON(encodeRequest(request));
    assert(json["protocolVersion"].integer == 1);
    assert(json["operation"].str == "inspect");
    assert("manifest" !in json.object);
    assert("options" !in json.object);

    request.operation = ProtocolOperation.transform;
    request.manifest.namespace = "demo";
    request.manifest.defaultPreset = "light";
    request.manifest.presets["light"] = Palette.init;
    request.options.mode = OutputMode.host;
    json = parseJSON(encodeRequest(request));
    assert(json["options"]["mode"].str == "host");
    assert(json["manifest"]["schemaVersion"].integer == 1);

    auto response = decodeResponse(
        `{"protocolVersion":1,"id":"test-1","operation":"inspect","ok":true,"result":{},"diagnostics":[]}`
    );
    assert(response.versionNumber == 1);
    assert(response.id == "test-1");
    assert(response.ok);
}
