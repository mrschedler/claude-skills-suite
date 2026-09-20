// Filter stdin JSON from interagent_assignments into unseen TSV lines.
// env SEEN = path to seen-file (one id per line). No project skip: this
// dispatcher is machine-wide; project is used only to pick --cwd.
const fs = require("fs");
let buf = "";
process.stdin.on("data", (c) => (buf += c));
process.stdin.on("end", () => {
  let rows;
  try {
    rows = JSON.parse(buf || "[]");
  } catch (e) {
    return;
  }
  if (!Array.isArray(rows)) return;
  const seenFile = process.env.SEEN;
  let seen = new Set();
  try {
    seen = new Set(fs.readFileSync(seenFile, "utf8").split(/\r?\n/).filter(Boolean));
  } catch (e) {}
  const fresh = [];
  for (const r of rows) {
    const id = String(r.id);
    if (seen.has(id)) continue;
    const refs = Array.isArray(r.refs) ? r.refs : [];
    const proj = refs.find((x) => x && x.type === "project");
    const project = proj && proj.id ? String(proj.id) : "-";
    const from = r.from || "?";
    const title = (r.title || "").replace(/[\t\r\n]+/g, " ");
    process.stdout.write(id + "\t" + project + "\t" + from + "\t" + title + "\n");
    fresh.push(id);
  }
  if (fresh.length) {
    try {
      fs.appendFileSync(seenFile, fresh.join("\n") + "\n");
    } catch (e) {}
  }
});
