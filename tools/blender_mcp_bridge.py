"""
Stdio MCP server that lets Claude Code drive Blender through Blender Lab's
official "MCP" add-on (extensions.blender.org id `mcp`).

The add-on listens on localhost:9876 and runs null-terminated JSON requests of
the form {"type": "execute", "code": ..., "strict_json": bool}. This script
speaks MCP over stdio and forwards each tool call to that socket. Standard
library only, so it runs on any Python 3.10+.

Register with:
    claude mcp add --scope user blender -- python <repo>/tools/blender_mcp_bridge.py
"""

import base64
import json
import os
import socket
import sys

HOST = os.environ.get("BLENDER_HOST", "localhost")
PORT = int(os.environ.get("BLENDER_PORT", "9876"))
TIMEOUT = float(os.environ.get("BLENDER_TIMEOUT", "300"))

SCENE_INFO_CODE = """
import bpy
scene = bpy.context.scene
result = {
    "blender": bpy.app.version_string,
    "file": bpy.data.filepath or "(unsaved)",
    "scene": scene.name,
    "frame": scene.frame_current,
    "objects": [
        {"name": o.name, "type": o.type, "location": [round(v, 3) for v in o.location],
         "dimensions": [round(v, 3) for v in o.dimensions]}
        for o in scene.objects
    ][:200],
}
"""

SCREENSHOT_CODE = """
import base64, os, tempfile, bpy
path = os.path.join(tempfile.gettempdir(), "blender_mcp_viewport.png")
area = next((a for w in bpy.context.window_manager.windows for a in w.screen.areas if a.type == "VIEW_3D"), None)
if area is None:
    raise RuntimeError("No 3D viewport is open")
window = next(w for w in bpy.context.window_manager.windows if area in w.screen.areas[:])
with bpy.context.temp_override(window=window, area=area):
    bpy.ops.screen.screenshot_area(filepath=path)
with open(path, "rb") as f:
    result = {"png_base64": base64.b64encode(f.read()).decode("ascii")}
os.remove(path)
"""

TOOLS = [
    {
        "name": "execute_python",
        "description": (
            "Run Python inside the live Blender session (bpy is available). "
            "Assign a JSON-serializable dict to `result` to return data; print() output is returned too."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"code": {"type": "string", "description": "Python code to run in Blender."}},
            "required": ["code"],
        },
    },
    {
        "name": "get_scene_info",
        "description": "Blender version, open file, and every object in the scene with type, location and size.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "viewport_screenshot",
        "description": "PNG screenshot of the first 3D viewport.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def blender_execute(code, strict_json=False):
    with socket.create_connection((HOST, PORT), timeout=TIMEOUT) as sock:
        sock.sendall((json.dumps({"type": "execute", "code": code, "strict_json": strict_json}) + "\0").encode())
        buf = bytearray()
        while b"\0" not in buf:
            chunk = sock.recv(65536)
            if not chunk:
                break
            buf.extend(chunk)
    return json.loads(bytes(buf).split(b"\0", 1)[0])


def as_text(response):
    parts = []
    if response.get("status") == "ok":
        parts.append(json.dumps(response.get("result", {}), indent=2))
    else:
        parts.append("Error: " + str(response.get("message", response)))
    for stream in ("stdout", "stderr"):
        if response.get(stream):
            parts.append("{}:\n{}".format(stream, response[stream]))
    return "\n\n".join(parts)


def call_tool(name, args):
    try:
        if name == "execute_python":
            response = blender_execute(args.get("code", ""))
        elif name == "get_scene_info":
            response = blender_execute(SCENE_INFO_CODE, strict_json=True)
        elif name == "viewport_screenshot":
            response = blender_execute(SCREENSHOT_CODE, strict_json=True)
            if response.get("status") == "ok":
                png = response["result"]["png_base64"]
                base64.b64decode(png, validate=True)
                return {"content": [{"type": "image", "data": png, "mimeType": "image/png"}]}
        else:
            return {"content": [{"type": "text", "text": "Unknown tool: " + name}], "isError": True}
    except OSError as ex:
        return {
            "content": [{"type": "text", "text": (
                "Could not reach Blender on {}:{} ({}). Is Blender open with the MCP add-on enabled "
                "and its server running (Preferences > Add-ons > MCP)?".format(HOST, PORT, ex))}],
            "isError": True,
        }
    return {"content": [{"type": "text", "text": as_text(response)}], "isError": response.get("status") != "ok"}


def handle(msg):
    method = msg.get("method")
    if method == "initialize":
        return {
            "protocolVersion": msg.get("params", {}).get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "blender-lab-bridge", "version": "1.0.0"},
        }
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        params = msg.get("params", {})
        return call_tool(params.get("name"), params.get("arguments") or {})
    if method == "ping":
        return {}
    raise LookupError(method)


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        msg = json.loads(line)
        if "id" not in msg:
            continue  # Notification.
        try:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "result": handle(msg)}
        except LookupError as ex:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32601, "message": "Method not found: {}".format(ex)}}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
