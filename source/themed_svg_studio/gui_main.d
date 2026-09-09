module themed_svg_studio.gui_main;

import tgc.gcobj;
import dui;
import std.conv : to;
import std.format : format;
import std.path : buildPath, dirName;
import std.stdio : stderr, writeln;
import themed_svg_studio;

private struct StudioShell
{
    EditorModel model;
    DuiApp app;
    State!string status;
    State!string editPreset;
    State!string editToken;
    State!string editValue;
    State!string bindingSelector;
    State!string bindingToken;
    State!string bindingAttribute;

    void initialize(uint width, uint height)
    {
        status = State!string("Ready — open an SVG and version 1 manifest.");
        editPreset = State!string(model.selectedPreset.length ? model.selectedPreset : "light");
        editToken = State!string(model.manifest.tokens.length ? model.manifest.tokens[0].id : "");
        editValue = State!string("");
        if (
            editPreset.value in model.manifest.presets
            && editToken.value in model.manifest.presets[editPreset.value]
        )
            editValue = model.manifest.presets[editPreset.value][editToken.value];
        bindingSelector = State!string("#element");
        bindingToken = State!string(editToken.value);
        bindingAttribute = State!string("fill");
        app.bind(status);
        app.bind(editPreset);
        app.bind(editToken);
        app.bind(editValue);
        app.bind(bindingSelector);
        app.bind(bindingToken);
        app.bind(bindingAttribute);
        app.init((ref UiBuilder ui) @trusted {
            return VStack(HStack(Text(productName).fontSize(22).bold(),
                Button("Open").onClick(() @trusted {
                    status = "Pass SVG and manifest paths when launching v0.1.0.";
                }), Button("Save").onClick(() @trusted { saveCurrent(); }),
                Button("Export").onClick(() @trusted { exportCurrent(); }),
                Button("Undo").onClick(() @trusted {
                    if (model.undo)
                        status = "Undid edit.";
                }), Button("Redo").onClick(() @trusted {
                    if (model.redo)
                        status = "Redid edit.";
                })).spacing(8), HStack(editorControls, inspector("Tokens", tokenSummary),
                inspector("Presets", presetSummary), inspector("Bindings", bindingSummary),
                VStack(Text("Preview")
                .fontSize(16).bold(), HStack(Button("Source").onClick(() @trusted {
                    choosePreview(PreviewMode.source);
                }), Button("Fixed").onClick(() @trusted {
                    choosePreview(PreviewMode.fixed);
                }), Button("Light").onClick(() @trusted {
                    choosePreview(PreviewMode.light);
                }), Button("Dark").onClick(() @trusted {
                    choosePreview(PreviewMode.dark);
                }), Button("Adaptive").onClick(() @trusted {
                    choosePreview(PreviewMode.standaloneAdaptive);
                }), Button("Host").onClick(() @trusted {
                    choosePreview(PreviewMode.host);
                })).spacing(4), Text(previewSummary)).spacing(6).padding(12)).spacing(12),
                HStack(Button("About").onClick(() @trusted { status = aboutText; }),
                Button("Help").onClick(() @trusted { status = helpText; }),
                Button("Debug dump").onClick(() @trusted {
                    status = debugDump(model.svgPath);
                }), Button("Update status").onClick(() @trusted {
                    status = updateStatus;
                })).spacing(8), Text(status.value).fontSize(12)).spacing(12).padding(16);
        }, new SoftwareBackend(width, height));
        app.resize(width, height);
        app.frame();
    }

    Widget editorControls()
    {
        return VStack(
            Text("Semantic editor").fontSize(16).bold(),
            formRow("Preset", boundTextField(editPreset, "light")),
            formRow("Token", boundTextField(editToken, "color.surface")),
            formRow("Value", boundTextField(editValue, "#ffffff")),
            Button("Set token value").onClick(() @trusted {
                if (!editPreset.value.length || !editToken.value.length || !editValue.value.length)
                {
                    status = "Preset, token, and value are required.";
                    return;
                }
                model.setTokenValue(editPreset.value, editToken.value, editValue.value);
                bindingToken = editToken.value;
                status = "Updated " ~ editToken.value ~ " in " ~ editPreset.value ~ ".";
            }),
            formRow("Selector", boundTextField(bindingSelector, "#element")),
            formRow("Binding token", boundTextField(bindingToken, "color.surface")),
            formRow("Attribute", boundTextField(bindingAttribute, "fill")),
            Button("Add binding").onClick(() @trusted {
                if (
                    !bindingSelector.value.length
                    || !bindingToken.value.length
                    || !bindingAttribute.value.length
                )
                {
                    status = "Selector, token, and attribute are required.";
                    return;
                }
                model.addBinding(Binding(
                    BindingKind.presentation,
                    bindingToken.value,
                    bindingSelector.value,
                    bindingAttribute.value
                ));
                status = "Added presentation binding.";
            })
        ).spacing(6).padding(12).width(280);
    }

    Widget inspector(string title, string summary)
    {
        return VStack(Text(title).fontSize(16).bold(), Text(summary)).spacing(6).padding(12);
    }

    string tokenSummary() const
    {
        if (!model.hasDocument)
            return "No document";
        string result = format("%s semantic token(s)", model.manifest.tokens.length);
        foreach (token; model.manifest.tokens)
            result ~= "\n" ~ token.id;
        return result;
    }

    string presetSummary() const
    {
        if (!model.hasDocument)
            return "No presets";
        string result = format("%s preset(s)", model.manifest.presets.length);
        foreach (name, palette; model.manifest.presets)
            result ~= "\n" ~ name ~ format(" (%s values)", palette.length);
        return result;
    }

    string bindingSummary() const
    {
        if (!model.hasDocument)
            return "No bindings";
        string result = format("%s explicit binding(s)", model.manifest.bindings.length);
        foreach (binding; model.manifest.bindings)
            result ~= "\n" ~ binding.selector ~ " → " ~ binding.token;
        return result;
    }

    string previewSummary() const
    {
        return model.previewSvg.length ? format("%s bytes",
                model.previewSvg.length) : "Preview appears after open/transform.";
    }

    void saveCurrent()
    {
        if (!model.hasDocument)
        {
            status = "Nothing to save.";
            return;
        }
        try
        {
            model.save;
            status = "Saved.";
        }
        catch (Exception error)
            status = "Save failed: " ~ error.msg;
    }

    void exportCurrent()
    {
        if (!model.hasDocument)
        {
            status = "Nothing to export.";
            return;
        }
        try
        {
            auto output = buildPath(dirName(model.svgPath), "themed-svg-export");
            model.exportTo(new JsonlProcessAdapter, output);
            status = "Exported to " ~ output;
        }
        catch (Exception error)
            status = "Export failed: " ~ error.msg;
    }

    void choosePreview(PreviewMode mode)
    {
        model.previewMode = mode;
        try
        {
            model.refreshPreview(new JsonlProcessAdapter);
            status = "Preview: " ~ cast(string) mode;
        }
        catch (Exception error)
            status = "Preview unavailable: " ~ error.msg;
    }
}

int main(string[] args)
{
    StudioShell shell;
    if (args.length == 3)
    {
        try
            shell.model.open(args[1], args[2]);
        catch (Exception error)
        {
            stderr.writeln("Open failed: ", error.msg);
            return 1;
        }
    }
    shell.initialize(1280, 800);

    version (ThemedSvgStudioHeadless)
    {
        writeln(aboutText);
        writeln("Headless software frame rendered.");
        return 0;
    }
    else version (Windows)
        return runWindowsHost(shell);
    else
    {
        writeln("Native window hosting is currently available on Windows.");
        writeln("The DUI/Dew software frame was rendered successfully.");
        return 0;
    }
}

version (Windows)
{
    version (ThemedSvgStudioHeadless)
    {
    }
    else
    {
        import core.sys.windows.windows;

        private __gshared StudioShell* activeShell;

        private extern (Windows) LRESULT windowProc(HWND hwnd, UINT message,
                WPARAM wParam, LPARAM lParam) nothrow
        {
            try
                switch (message)
            {
            case WM_SIZE:
                if (activeShell !is null)
                {
                    activeShell.app.resize(LOWORD(lParam), HIWORD(lParam));
                    activeShell.app.frame();
                    InvalidateRect(hwnd, null, TRUE);
                }
                return 0;
            case WM_PAINT:
                PAINTSTRUCT paint;
                auto dc = BeginPaint(hwnd, &paint);
                auto backend = cast(SoftwareBackend) activeShell.app.dew.backend;
                if (backend !is null && backend.pixels.length)
                {
                    BITMAPINFO bitmap;
                    bitmap.bmiHeader.biSize = BITMAPINFOHEADER.sizeof;
                    bitmap.bmiHeader.biWidth = backend.width;
                    bitmap.bmiHeader.biHeight = -cast(int) backend.height;
                    bitmap.bmiHeader.biPlanes = 1;
                    bitmap.bmiHeader.biBitCount = 32;
                    bitmap.bmiHeader.biCompression = BI_RGB;
                    StretchDIBits(dc, 0, 0, backend.width, backend.height, 0,
                            0, backend.width, backend.height, backend.pixels.ptr,
                            &bitmap, DIB_RGB_COLORS, SRCCOPY);
                }
                EndPaint(hwnd, &paint);
                return 0;
            case WM_LBUTTONDOWN:
            case WM_LBUTTONUP:
            case WM_MOUSEMOVE:
                PointerEvent event;
                event.x = cast(float) cast(short) LOWORD(lParam);
                event.y = cast(float) cast(short) HIWORD(lParam);
                event.kind = PointerKind.Mouse;
                event.button = PointerButton.Left;
                event.primary = true;
                event.pressed = message != WM_LBUTTONUP
                    && ((wParam & MK_LBUTTON) != 0 || message == WM_LBUTTONDOWN);
                event.phase = message == WM_LBUTTONDOWN ? PointerPhase.Down
                    : message == WM_LBUTTONUP ? PointerPhase.Up : PointerPhase.Move;
                activeShell.app.pointer(event);
                activeShell.app.frame();
                InvalidateRect(hwnd, null, FALSE);
                return 0;
            case WM_CHAR:
                {
                    string key;
                    if (wParam == 8)
                        key = "Backspace";
                    else if (wParam == 13)
                        key = "Enter";
                    else if (wParam >= 32)
                        key = to!string(cast(dchar) wParam);
                    if (key.length)
                    {
                        activeShell.app.key(keyDown(key, GetKeyState(VK_SHIFT) < 0));
                        activeShell.app.frame();
                        InvalidateRect(hwnd, null, FALSE);
                    }
                }
                return 0;
            case WM_KEYDOWN:
                if (wParam == VK_TAB)
                {
                    activeShell.app.key(keyDown("Tab", GetKeyState(VK_SHIFT) < 0));
                    activeShell.app.frame();
                    InvalidateRect(hwnd, null, FALSE);
                    return 0;
                }
                return DefWindowProcA(hwnd, message, wParam, lParam);
            case WM_DESTROY:
                PostQuitMessage(0);
                return 0;
            default:
                return DefWindowProcA(hwnd, message, wParam, lParam);
            }
            catch (Exception)
                return DefWindowProcA(hwnd, message, wParam, lParam);
        }

        private int runWindowsHost(ref StudioShell shell)
        {
            activeShell = &shell;
            auto instance = GetModuleHandleA(null);
            WNDCLASSA windowClass;
            windowClass.lpfnWndProc = &windowProc;
            windowClass.hInstance = instance;
            windowClass.lpszClassName = "ThemedSvgStudioDuiHost";
            windowClass.hCursor = LoadCursorA(null, cast(LPCSTR) 32512);
            windowClass.hbrBackground = cast(HBRUSH)(COLOR_WINDOW + 1);
            if (!RegisterClassA(&windowClass) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS)
                return 1;
            auto hwnd = CreateWindowExA(0, windowClass.lpszClassName, productName.ptr, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                    CW_USEDEFAULT, CW_USEDEFAULT, 1280, 800, null, null, instance, null);
            if (hwnd is null)
                return 1;
            MSG message;
            while (GetMessageA(&message, null, 0, 0) > 0)
            {
                TranslateMessage(&message);
                DispatchMessageA(&message);
            }
            return cast(int) message.wParam;
        }
    }
}
