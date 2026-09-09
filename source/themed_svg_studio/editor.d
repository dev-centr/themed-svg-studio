/// Semantic editor model: document lifecycle, history, diagnostics, and export.
module themed_svg_studio.editor;

import dui : UndoStack;
import std.conv : to;
import std.datetime.systime : Clock;
import std.exception : enforce;
import std.file : exists, mkdirRecurse, readText, write;
import std.json;
import std.path : buildPath, dirName;
import std.string : strip;
import themed_svg_studio.diagnostics;
import themed_svg_studio.manifest;
import themed_svg_studio.process_adapter;
import themed_svg_studio.protocol;

enum PreviewMode : string
{
    source = "source",
    fixed = "fixed",
    light = "light",
    dark = "dark",
    standaloneAdaptive = "standalone-adaptive",
    host = "host"
}

struct DocumentSnapshot
{
    string svg;
    string manifestJson;
    string preset;
    PreviewMode previewMode;
}

struct EditorModel
{
    string svgPath;
    string manifestPath;
    string svg;
    Manifest manifest;
    string selectedPreset;
    PreviewMode previewMode = PreviewMode.host;
    DiagnosticsModel diagnostics;
    string previewSvg;
    string savedFingerprint;
    UndoStack!DocumentSnapshot history;

    bool hasDocument() const
    {
        return svg.length > 0 || manifest.namespace.length > 0;
    }

    string fingerprint() const
    {
        return svg ~ "\n--manifest--\n" ~ serializeManifest(manifest, false);
    }

    bool isDirty() const
    {
        return hasDocument && fingerprint != savedFingerprint;
    }

    DocumentSnapshot snapshot() const
    {
        return DocumentSnapshot(svg, serializeManifest(manifest, false),
                selectedPreset, previewMode);
    }

    void restore(const DocumentSnapshot value)
    {
        svg = value.svg;
        manifest = parseManifest(value.manifestJson);
        selectedPreset = value.preset;
        previewMode = value.previewMode;
    }

    void checkpoint()
    {
        history.push(snapshot);
    }

    bool undo()
    {
        auto current = snapshot;
        if (!history.popUndo(current))
            return false;
        restore(current);
        return true;
    }

    bool redo()
    {
        auto current = snapshot;
        if (!history.popRedo(current))
            return false;
        restore(current);
        return true;
    }

    void open(string svgFile, string manifestFile)
    {
        enforce(exists(svgFile), "SVG file does not exist: " ~ svgFile);
        enforce(exists(manifestFile), "Manifest file does not exist: " ~ manifestFile);
        svgPath = svgFile;
        manifestPath = manifestFile;
        svg = readText(svgFile);
        manifest = parseManifest(readText(manifestFile));
        selectedPreset = manifest.defaultPreset;
        savedFingerprint = fingerprint;
        history.clear();
        diagnostics.clear();
        previewSvg = svg;
    }

    void save()
    {
        enforce(svgPath.length && manifestPath.length, "Save paths are not set.");
        write(svgPath, svg);
        write(manifestPath, serializeManifest(manifest));
        savedFingerprint = fingerprint;
    }

    void saveAs(string svgFile, string manifestFile)
    {
        svgPath = svgFile;
        manifestPath = manifestFile;
        if (dirName(svgFile).length)
            mkdirRecurse(dirName(svgFile));
        if (dirName(manifestFile).length)
            mkdirRecurse(dirName(manifestFile));
        save();
    }

    void setTokenValue(string preset, string token, string value)
    {
        checkpoint();
        bool knownToken;
        foreach (candidate; manifest.tokens)
            if (candidate.id == token)
            {
                knownToken = true;
                break;
            }
        if (!knownToken)
            manifest.tokens ~= SemanticToken(token);
        if (preset !in manifest.presets)
            manifest.presets[preset] = Palette.init;
        manifest.presets[preset][token] = value;
        selectedPreset = preset;
    }

    void addBinding(Binding binding)
    {
        checkpoint();
        manifest.bindings ~= binding;
    }

    void removeBinding(size_t index)
    {
        enforce(index < manifest.bindings.length, "Binding index is out of range.");
        checkpoint();
        manifest.bindings = manifest.bindings[0 .. index] ~ manifest.bindings[index + 1 .. $];
    }

    ProtocolResponse run(ProtocolAdapter adapter, ProtocolOperation operation)
    {
        ProtocolRequest request;
        request.id = "studio-" ~ Clock.currTime.stdTime.to!string;
        request.operation = operation;
        request.svg = svg;
        request.manifest = manifest;
        request.options.preset = selectedPreset;
        request.options.mode = previewOutputMode;
        auto response = adapter.call(request);
        diagnostics.replace(response.diagnostics);
        return response;
    }

    void refreshPreview(ProtocolAdapter adapter)
    {
        if (previewMode == PreviewMode.source)
        {
            previewSvg = svg;
            return;
        }
        auto response = run(adapter, ProtocolOperation.transform);
        if (response.ok && response.result.type == JSONType.object)
        {
            const key = previewMode == PreviewMode.dark
                ? "darkSvg" : previewMode == PreviewMode.light ? "lightSvg" : "svg";
            if (auto value = key in response.result.object)
                previewSvg = value.str;
        }
    }

    void exportTo(ProtocolAdapter adapter, string outputDirectory)
    {
        auto response = run(adapter, ProtocolOperation.exportArtifacts);
        enforce(response.ok, response.error.length ? response.error : "Export failed.");
        mkdirRecurse(outputDirectory);
        if (auto artifacts = "artifacts" in response.result.object)
            foreach (name, value; artifacts.object)
                if (value.type == JSONType.string)
                    write(buildPath(outputDirectory, name ~ ".svg"), value.str);
    }

    OutputMode previewOutputMode() const
    {
        final switch (previewMode)
        {
        case PreviewMode.fixed:
            return OutputMode.fixed;
        case PreviewMode.light:
            return OutputMode.pairedFixed;
        case PreviewMode.dark:
            return OutputMode.pairedFixed;
        case PreviewMode.standaloneAdaptive:
            return OutputMode.standaloneAdaptive;
        case PreviewMode.host:
            return OutputMode.host;
        case PreviewMode.source:
            return OutputMode.host;
        }
    }
}

unittest
{
    EditorModel model;
    model.svg = "<svg/>";
    model.manifest.namespace = "demo";
    model.manifest.defaultPreset = "light";
    model.manifest.presets["light"] = ["color.canvas": "#fff"];
    model.selectedPreset = "light";
    model.savedFingerprint = model.fingerprint;
    assert(!model.isDirty);
    model.setTokenValue("light", "color.canvas", "#000");
    assert(model.isDirty);
    assert(model.undo);
    assert(model.manifest.presets["light"]["color.canvas"] == "#fff");
    assert(model.redo);
}
