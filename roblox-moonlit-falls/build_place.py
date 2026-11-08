"""Pack src/ into MoonlitFalls.rbxlx so it opens straight in Roblox Studio."""
from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "src"
ref = 0


def nid():
    global ref
    ref += 1
    return f"RBX{ref:08d}"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def item(cls, name, children="", source=None):
    props = f'<string name="Name">{esc(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source"><![CDATA[{source.replace("]]>", "]]]]><![CDATA[>")}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="{nid()}"><Properties>{props}</Properties>{children}</Item>\n'


def script(path: Path):
    name = path.name
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript")):
        if name.endswith(suffix):
            return item(cls, name[: -len(suffix)], source=path.read_text())
    return item("ModuleScript", path.stem, source=path.read_text())


def folder(name, path: Path):
    return item("Folder", name, "".join(script(p) for p in sorted(path.glob("*.luau"))))


xml = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
    + item("Workspace", "Workspace")
    + item("Lighting", "Lighting")
    + item("ReplicatedStorage", "ReplicatedStorage", folder("Shared", SRC / "shared"))
    + item("ServerScriptService", "ServerScriptService", folder("Server", SRC / "server"))
    + item("StarterPlayer", "StarterPlayer", item("StarterPlayerScripts", "StarterPlayerScripts", folder("Client", SRC / "client")))
    + item("Teams", "Teams")
    + "</roblox>\n"
)
(ROOT / "MoonlitFalls.rbxlx").write_text(xml)
print("wrote MoonlitFalls.rbxlx")
