/// Diagnostics shared by the editor, CLI, and protocol adapter.
module themed_svg_studio.diagnostics;

import std.algorithm : count;
import std.array : appender;
import std.format : formattedWrite;
import std.json;

enum Severity : string
{
    warning = "warning",
    error = "error"
}

struct DiagnosticSource
{
    string kind;
    string path;
    size_t line;
    size_t column;
    string excerpt;
}

struct Diagnostic
{
    string code;
    Severity severity;
    string message;
    long bindingIndex = -1;
    string selector;
    DiagnosticSource source;
}

struct DiagnosticsModel
{
    Diagnostic[] items;

    void replace(Diagnostic[] diagnostics)
    {
        items = diagnostics.dup;
    }

    void clear()
    {
        items.length = 0;
    }

    size_t errorCount() const
    {
        return items.count!(item => item.severity == Severity.error);
    }

    size_t warningCount() const
    {
        return items.count!(item => item.severity == Severity.warning);
    }

    bool hasErrors() const
    {
        return errorCount > 0;
    }

    string summary() const
    {
        auto output = appender!string;
        output.formattedWrite("%s error(s), %s warning(s)", errorCount, warningCount);
        return output.data;
    }
}

Diagnostic diagnosticFromJson(JSONValue value)
{
    Diagnostic result;
    result.code = value["code"].str;
    result.severity = value["severity"].str == "error" ? Severity.error : Severity.warning;
    result.message = value["message"].str;
    if (auto index = "bindingIndex" in value.object)
        result.bindingIndex = index.integer;
    if (auto selector = "selector" in value.object)
        result.selector = selector.str;
    if (auto source = "source" in value.object)
    {
        if (auto kind = "kind" in source.object)
            result.source.kind = kind.str;
        if (auto path = "path" in source.object)
            result.source.path = path.str;
        if (auto line = "line" in source.object)
            result.source.line = cast(size_t) line.integer;
        if (auto column = "column" in source.object)
            result.source.column = cast(size_t) column.integer;
        if (auto excerpt = "excerpt" in source.object)
            result.source.excerpt = excerpt.str;
    }
    return result;
}

unittest
{
    DiagnosticsModel model;
    model.items = [
        Diagnostic("bad", Severity.error, "Bad input"),
        Diagnostic("note", Severity.warning, "Check this")
    ];
    assert(model.errorCount == 1);
    assert(model.warningCount == 1);
}
