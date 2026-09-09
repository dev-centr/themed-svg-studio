/// JSONL process boundary; deliberately isolated from protocol message types.
module themed_svg_studio.process_adapter;

import std.array : appender;
import std.conv : to;
import std.exception : enforce;
import std.file : exists, thisExePath;
import std.path : buildPath, dirName;
import std.process;
import std.stdio : File;
import std.string : strip;
import themed_svg_studio.protocol;

interface ProtocolAdapter
{
    ProtocolResponse call(ProtocolRequest request);
}

final class JsonlProcessAdapter : ProtocolAdapter
{
    private string[] command;

    this(string[] command = null)
    {
        if (!command.length)
            command = defaultProtocolCommand;
        enforce(command.length > 0, "Protocol command cannot be empty.");
        this.command = command.dup;
    }

    override ProtocolResponse call(ProtocolRequest request)
    {
        auto pipes = pipeProcess(command, Redirect.all);
        pipes.stdin.writeln(encodeRequest(request));
        pipes.stdin.close();

        auto responseLine = pipes.stdout.readln();
        auto errorText = appender!string;
        foreach (line; pipes.stderr.byLineCopy())
            errorText ~= line;
        const status = wait(pipes.pid);

        enforce(responseLine.strip.length > 0, "themed-svg returned no JSONL response" ~ (
                errorText.data.length ? ": " ~ errorText.data.strip : "."));
        auto response = decodeResponse(responseLine);
        enforce(response.versionNumber == protocolVersion,
                "Unsupported themed-svg protocol response version.");
        enforce(response.id == request.id, "Mismatched themed-svg response id.");
        if (status != 0 && response.error.length == 0)
            response.error = "themed-svg exited with status " ~ status.to!string;
        return response;
    }
}

private string[] defaultProtocolCommand()
{
    auto configured = environment.get("THEMED_SVG_STDIO", "");
    if (configured.length)
        return [configured];

    version (Windows)
    {
        const sibling = buildPath(dirName(thisExePath), "themed-svg-stdio.cmd");
        if (exists(sibling))
            return [sibling];
        auto appData = environment.get("APPDATA", "");
        if (appData.length)
        {
            const npmGlobal = buildPath(appData, "npm", "themed-svg-stdio.cmd");
            if (exists(npmGlobal))
                return [npmGlobal];
        }
        return ["themed-svg-stdio.cmd"];
    }
    else
        return ["themed-svg-stdio"];
}

final class RecordingAdapter : ProtocolAdapter
{
    ProtocolRequest[] requests;
    ProtocolResponse nextResponse;

    override ProtocolResponse call(ProtocolRequest request)
    {
        requests ~= request;
        return nextResponse;
    }
}

unittest
{
    auto adapter = new RecordingAdapter;
    adapter.nextResponse = ProtocolResponse(1, "r1", true);
    ProtocolRequest request;
    request.id = "r1";
    request.operation = ProtocolOperation.validate;
    assert(adapter.call(request).ok);
    assert(adapter.requests.length == 1);
}
