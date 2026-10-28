# Commands Claude should verify, not blindly assume

```sh
# safe read-only probes
pwd
git status --short
rojo --version
rojo --help
blender --version

# once the dedicated repo and project exist
rojo build default.project.json -o build/EscapeFromBloxov.rbxlx
rojo serve default.project.json

# optional only if installed and repo configured
stylua --check src
selene src
```

Notes: Roblox Studio must import/playtest a built place to validate behaviors; Rojo build alone does not demonstrate gameplay. A Rojo place build may exclude separately imported binary asset packages unless their asset references/scene assembly are accounted for. Prefer preserving map models in Studio-managed asset packages or .rbxmx/.rbxm fixtures with reproducible import scripts; document exactly where the authoritative map source lives. Never assume Rojo will serialize manually imported MeshPart binary data into text code mappings automatically.
