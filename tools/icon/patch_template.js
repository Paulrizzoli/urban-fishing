// Copies Godot's Windows export template and writes the game's icon (godot/icon.ico) and
// version info (name, version from project.godot) into the copy. Godot 4.4 can only do this
// itself on Windows with rcedit, so tools/build_windows.sh exports with the patched copy instead.
// usage: node patch_template.js <template.exe in> <template.exe out> <icon.ico> <version, like 0.9.10>
const fs = require('fs');
const PE = require('pe-library');
const ResEdit = require('resedit');
const [src, dst, ico, ver] = process.argv.slice(2);
const exe = PE.NtExecutable.from(fs.readFileSync(src), { ignoreCert: true });
const res = PE.NtExecutableResource.from(exe);
const iconFile = ResEdit.Data.IconFile.from(fs.readFileSync(ico));
const lang = 1033;
for (const g of ResEdit.Resource.IconGroupEntry.fromEntries(res.entries)) {
  ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, g.id, g.lang, iconFile.icons.map(i => i.data));
}
const vi = ResEdit.Resource.VersionInfo.fromEntries(res.entries)[0];
const parts = ver.split('.').map(Number); while (parts.length < 4) parts.push(0);
vi.setFileVersion(...parts, lang); vi.setProductVersion(...parts, lang);
vi.setStringValues({ lang, codepage: 1200 }, {
  CompanyName: 'Urban Fishing', FileDescription: 'Urban Fishing', ProductName: 'Urban Fishing',
  InternalName: 'Urban Fishing', OriginalFilename: 'Urban Fishing.exe',
  FileVersion: ver, ProductVersion: ver, LegalCopyright: '', Comments: 'Made with Godot Engine',
});
vi.outputToResourceEntries(res.entries);
res.outputResource(exe);
fs.writeFileSync(dst, Buffer.from(exe.generate()));
console.log(dst);
