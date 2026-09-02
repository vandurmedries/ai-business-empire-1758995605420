import { readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const root = new URL("..", import.meta.url).pathname;
const directories = ["api", "lib", "scripts", "tests"];
const files = [];

function walk(directory) {
  for (const entry of readdirSync(directory)) {
    const fullPath = join(directory, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) walk(fullPath);
    else if ((entry.endsWith(".js") || entry.endsWith(".mjs")) && !fullPath.endsWith("check.mjs")) files.push(fullPath);
  }
}

for (const directory of directories) walk(join(root, directory));
for (const file of files) {
  const result = spawnSync(process.execPath, ["--check", file], { encoding: "utf8" });
  if (result.status !== 0) {
    console.error(`Syntax check failed: ${relative(root, file)}`);
    console.error(result.stderr || result.stdout);
    process.exit(result.status || 1);
  }
}
console.log(`Checked ${files.length} JavaScript files.`);
