module editor_model_test;

import std.json : JSONType, JSONValue;
import themed_svg_studio;

unittest
{
    EditorModel model;
    model.svg = `<svg viewBox="0 0 10 10"><rect id="panel"/></svg>`;
    model.manifest.namespace = "sample";
    model.manifest.defaultPreset = "light";
    model.manifest.tokens = [SemanticToken("color.surface", "Panel surface")];
    model.manifest.presets["light"] = ["color.surface": "#ffffff"];
    model.selectedPreset = "light";
    model.savedFingerprint = model.fingerprint;

    model.addBinding(Binding(BindingKind.presentation, "color.surface", "#panel", "fill"));
    assert(model.isDirty);
    assert(model.manifest.bindings.length == 1);
    assert(model.undo);
    assert(model.manifest.bindings.length == 0);

    model.setTokenValue("dark", "color.accent", "#ff0000");
    assert(model.manifest.tokens[$ - 1].id == "color.accent");
    assert(model.manifest.presets["dark"]["color.accent"] == "#ff0000");
}

unittest
{
    auto adapter = new RecordingAdapter;
    JSONValue[string] inspection;
    inspection["elementCount"] = 2;
    adapter.nextResponse = ProtocolResponse(1, "ignored", true, JSONValue(inspection));

    ProtocolRequest request;
    request.id = "inspect-test";
    request.operation = ProtocolOperation.inspect;
    adapter.nextResponse.id = request.id;

    auto response = adapter.call(request);
    assert(response.ok);
    assert(response.result.type == JSONType.object);
    assert(response.result["elementCount"].integer == 2);
}
