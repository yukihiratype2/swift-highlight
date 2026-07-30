#!/usr/bin/env node
"use strict";
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const { createJiti } = require("jiti");
const args = process.argv.slice(2);
function value(flag, fallback) {
  const i = args.indexOf(flag); return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}
const upstream = path.resolve(value("--upstream", ""));
const output = path.resolve(value(
  "--output", path.join(__dirname, "..", "Sources", "HighlightSwift", "Resources", "Grammars")
));
if (!fs.existsSync(path.join(upstream, "src", "highlight.js"))) {
  throw new Error("Use --upstream PATH to a Highlight.js source checkout");
}
const jiti = createJiti(path.join(__dirname, "migrate-highlightjs.cjs"), {
  interopDefault: false, moduleCache: false
});
const coreModule = jiti(path.join(upstream, "src", "highlight.js"));
const hljs = coreModule.default || coreModule;
hljs.debugMode();
const skipped = new Set([
  "matcher", "beginRe", "endRe", "illegalRe", "keywordPatternRe",
  "compilerExtensions", "rawDefinition", "isCompiled"
]);
function encodeGraph(root) {
  const ids = new Map(), nodes = [], callbacks = new Map();
  function encode(x) {
    if (x === null || x === undefined) return x ?? null;
    if (x instanceof RegExp) return {$regex:{source:x.source,flags:[...x.flags].sort().join("")}};
    if (typeof x === "function") {
      const source = Function.prototype.toString.call(x);
      const sha256 = crypto.createHash("sha256").update(source).digest("hex");
      callbacks.set(sha256, {name:x.name||null,source,sha256});
      return {$callback:sha256};
    }
    if (typeof x !== "object") return x;
    if (ids.has(x)) return {$ref:ids.get(x)};
    const id = nodes.length;
    ids.set(x, id);
    const node = Array.isArray(x) ? {kind:"array",values:[]} : {kind:"object",values:{}};
    nodes.push(node);
    if (Array.isArray(x)) node.values = x.map(encode);
    else {
      if (x.matcher && typeof x.matcher.getMatcher === "function") {
        const matcher = x.matcher.getMatcher(0);
        if (matcher?.matcherRe instanceof RegExp) {
          node.values.__nativeMatcher = encode(matcher.matcherRe);
          node.values.__nativeMatcherDispatch = encode(
            Object.entries(matcher.matchIndexes).map(([group, options]) => ({
              group:Number(group), type:options.type, rule:options.rule||null
            })).sort((a,b)=>a.group-b.group)
          );
        }
      }
      for (const key of Object.keys(x).sort()) if (!skipped.has(key)) node.values[key] = encode(x[key]);
    }
    return {$ref:id};
  }
  return {
    root: encode(root).$ref, nodes,
    callbacks:[...callbacks.values()].sort((a,b)=>a.sha256.localeCompare(b.sha256))
  };
}
const files = fs.readdirSync(path.join(upstream, "src", "languages"))
  .filter(x=>x.endsWith(".js")).sort();
const languages = [];
for (const filename of files) {
  const id = path.basename(filename, ".js");
  const imported = jiti(path.join(upstream, "src", "languages", filename));
  hljs.registerLanguage(id, imported.default || imported);
  hljs.highlight("", {language:id,ignoreIllegals:true});
  const grammar = hljs.getLanguage(id);
  languages.push({
    id, aliases:[...new Set(grammar.aliases||[])].sort(),
    disableAutodetect:Boolean(grammar.disableAutodetect), graph:encodeGraph(grammar)
  });
}
const pkg = JSON.parse(fs.readFileSync(path.join(upstream, "package.json")));
const upstreamInfo = {name:pkg.name,version:pkg.version,repository:pkg.repository};
fs.mkdirSync(output,{recursive:true});
fs.writeFileSync(path.join(output,"catalog.json"), JSON.stringify({
  schemaVersion:1,generator:"HighlightSwift/Tools/migrate-highlightjs.cjs",
  upstream:upstreamInfo,languages:languages.map(({id,aliases,disableAutodetect})=>({
    id,aliases,disableAutodetect
  }))
})+"\n");
let bytes=0;
for (const language of languages) {
  const body=JSON.stringify({schemaVersion:1,upstream:upstreamInfo,language})+"\n";
  fs.writeFileSync(path.join(output,`${language.id}.json`),body); bytes+=Buffer.byteLength(body);
}
console.log(`Migrated ${languages.length} languages, ${bytes} bytes -> ${output}`);
