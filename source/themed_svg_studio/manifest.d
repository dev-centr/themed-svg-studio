/// Version 1 themed-SVG manifest types and JSON conversion.
module themed_svg_studio.manifest;

import std.array : array;
import std.json;

enum BindingKind : string
{
    presentation = "presentation",
    inlineStyle = "inline-style",
    stylesheet = "stylesheet",
    gradientStop = "gradient-stop"
}

enum OutputMode : string
{
    fixed = "fixed",
    standaloneAdaptive = "standalone-adaptive",
    host = "host",
    pairedFixed = "paired-fixed"
}

struct SourceProvenance
{
    string kind;
    string uri;
    string generator;
    string generatedAt;
}

struct SemanticToken
{
    string id;
    string description;
}

struct Binding
{
    BindingKind kind;
    string token;
    string selector;
    string attribute;
    string property;
    string styleSelector;
}

struct FallbackBehavior
{
    string unresolvedToken = "error";
    string missingTarget = "warn";
}

alias Palette = string[string];

struct Manifest
{
    int schemaVersion = 1;
    string namespace;
    SourceProvenance source;
    SemanticToken[] tokens;
    string defaultPreset;
    Palette[string] presets;
    Palette lightOverrides;
    Palette darkOverrides;
    Binding[] bindings;
    FallbackBehavior fallback;
}

private string optionalString(JSONValue object, string key)
{
    auto found = key in object.object;
    return found is null || found.type != JSONType.string ? "" : found.str;
}

private Palette parsePalette(JSONValue value)
{
    Palette palette;
    foreach (key, item; value.object)
        palette[key] = item.str;
    return palette;
}

Manifest parseManifest(string text)
{
    const root = parseJSON(text);
    Manifest result;
    result.schemaVersion = cast(int) root["schemaVersion"].integer;
    result.namespace = root["namespace"].str;
    result.defaultPreset = root["defaultPreset"].str;

    if (auto value = "source" in root.object)
    {
        result.source.kind = optionalString(*value, "kind");
        result.source.uri = optionalString(*value, "uri");
        result.source.generator = optionalString(*value, "generator");
        result.source.generatedAt = optionalString(*value, "generatedAt");
    }
    foreach (item; root["tokens"].array)
        result.tokens ~= SemanticToken(item["id"].str, optionalString(item, "description"));
    foreach (name, palette; root["presets"].object)
        result.presets[name] = parsePalette(palette);
    if (auto overrides = "paletteOverrides" in root.object)
    {
        if (auto light = "light" in overrides.object)
            result.lightOverrides = parsePalette(*light);
        if (auto dark = "dark" in overrides.object)
            result.darkOverrides = parsePalette(*dark);
    }
    foreach (item; root["bindings"].array)
    {
        Binding binding;
        const kind = item["kind"].str;
        switch (kind)
        {
        case "presentation":
            binding.kind = BindingKind.presentation;
            break;
        case "inline-style":
            binding.kind = BindingKind.inlineStyle;
            break;
        case "stylesheet":
            binding.kind = BindingKind.stylesheet;
            break;
        case "gradient-stop":
            binding.kind = BindingKind.gradientStop;
            break;
        default:
            throw new JSONException("Unknown binding kind: " ~ kind);
        }
        binding.token = item["token"].str;
        binding.selector = item["selector"].str;
        binding.attribute = optionalString(item, "attribute");
        binding.property = optionalString(item, "property");
        binding.styleSelector = optionalString(item, "styleSelector");
        result.bindings ~= binding;
    }
    if (auto fallback = "fallback" in root.object)
    {
        auto unresolved = optionalString(*fallback, "unresolvedToken");
        auto missing = optionalString(*fallback, "missingTarget");
        if (unresolved.length)
            result.fallback.unresolvedToken = unresolved;
        if (missing.length)
            result.fallback.missingTarget = missing;
    }
    return result;
}

private JSONValue paletteJson(const Palette palette)
{
    JSONValue[string] values;
    foreach (key, value; palette)
        values[key] = JSONValue(value);
    return JSONValue(values);
}

JSONValue manifestJson(const Manifest manifest)
{
    JSONValue[string] root;
    root["schemaVersion"] = manifest.schemaVersion;
    root["namespace"] = manifest.namespace;
    root["defaultPreset"] = manifest.defaultPreset;

    if (manifest.source.kind.length)
    {
        JSONValue[string] source;
        source["kind"] = manifest.source.kind;
        if (manifest.source.uri.length)
            source["uri"] = manifest.source.uri;
        if (manifest.source.generator.length)
            source["generator"] = manifest.source.generator;
        if (manifest.source.generatedAt.length)
            source["generatedAt"] = manifest.source.generatedAt;
        root["source"] = source;
    }

    JSONValue[] tokens;
    foreach (token; manifest.tokens)
    {
        JSONValue[string] value = ["id": JSONValue(token.id)];
        if (token.description.length)
            value["description"] = token.description;
        tokens ~= JSONValue(value);
    }
    root["tokens"] = tokens;

    JSONValue[string] presets;
    foreach (name, palette; manifest.presets)
        presets[name] = paletteJson(palette);
    root["presets"] = presets;

    if (manifest.lightOverrides.length || manifest.darkOverrides.length)
    {
        JSONValue[string] overrides;
        if (manifest.lightOverrides.length)
            overrides["light"] = paletteJson(manifest.lightOverrides);
        if (manifest.darkOverrides.length)
            overrides["dark"] = paletteJson(manifest.darkOverrides);
        root["paletteOverrides"] = overrides;
    }

    JSONValue[] bindings;
    foreach (binding; manifest.bindings)
    {
        JSONValue[string] value;
        value["kind"] = cast(string) binding.kind;
        value["token"] = binding.token;
        value["selector"] = binding.selector;
        if (binding.attribute.length)
            value["attribute"] = binding.attribute;
        if (binding.property.length)
            value["property"] = binding.property;
        if (binding.styleSelector.length)
            value["styleSelector"] = binding.styleSelector;
        bindings ~= JSONValue(value);
    }
    root["bindings"] = bindings;

    JSONValue[string] fallback;
    fallback["unresolvedToken"] = manifest.fallback.unresolvedToken;
    fallback["missingTarget"] = manifest.fallback.missingTarget;
    root["fallback"] = fallback;
    return JSONValue(root);
}

string serializeManifest(const Manifest manifest, bool pretty = true)
{
    auto value = manifestJson(manifest);
    return pretty ? value.toPrettyString : value.toString(JSONOptions.doNotEscapeSlashes);
}

unittest
{
    enum sample = `{"schemaVersion":1,"namespace":"demo","tokens":[{"id":"color.canvas"}],"defaultPreset":"light","presets":{"light":{"color.canvas":"#fff"}},"bindings":[{"kind":"presentation","token":"color.canvas","selector":"svg","attribute":"fill"}]}`;
    auto parsed = parseManifest(sample);
    assert(parsed.namespace == "demo");
    assert(parsed.tokens.length == 1);
    assert(parsed.bindings[0].attribute == "fill");
    assert(parseManifest(serializeManifest(parsed)).defaultPreset == "light");
}
