#!/usr/bin/env node
"use strict";
const fs=require("fs"),path=require("path");
const {createJiti}=require(path.join(__dirname,"..","Tools","node_modules","jiti"));
const upstream=path.resolve("../highlightjs-reference");
const defs=JSON.parse(fs.readFileSync("Benchmarks/workloads.json"));
const workloads=defs.map(x=>({...x,source:Array(x.repeat).fill(x.snippet).join("\n")}));
const t0=process.hrtime.bigint();
const jiti=createJiti(path.join(__dirname,"highlightjs.cjs"),{interopDefault:false,moduleCache:true});
const cm=jiti(path.join(upstream,"src","highlight.js")),hljs=cm.default||cm;
for(const l of new Set(workloads.map(x=>x.language))){
 const m=jiti(path.join(upstream,"src","languages",`${l}.js`));hljs.registerLanguage(l,m.default||m);
}
const initialization_seconds=Number(process.hrtime.bigint()-t0)/1e9;
const iterations=25,warmups=3,rows=[];let checksum=0,total_bytes=0,total_seconds=0;
for(const w of workloads){
 let s=process.hrtime.bigint();checksum+=hljs.highlight(w.source,{language:w.language}).value.length;
 const first_highlight_seconds=Number(process.hrtime.bigint()-s)/1e9;
 for(let i=0;i<warmups;i++)checksum+=hljs.highlight(w.source,{language:w.language}).value.length;
 s=process.hrtime.bigint();
 for(let i=0;i<iterations;i++)checksum+=hljs.highlight(w.source,{language:w.language}).value.length;
 const seconds=Number(process.hrtime.bigint()-s)/1e9,bytes=Buffer.byteLength(w.source);
 total_bytes+=bytes*iterations;total_seconds+=seconds;
 rows.push({name:w.name,language:w.language,bytes,seconds,first_highlight_seconds,
  mb_per_second:bytes*iterations/1e6/seconds});
}
console.log(JSON.stringify({runtime:"highlight.js-node",checksum,initialization_seconds,iterations,warmups,
 peak_rss_kb:process.resourceUsage().maxRSS,total_bytes,total_seconds,
 total_mb_per_second:total_bytes/1e6/total_seconds,workloads:rows}));
