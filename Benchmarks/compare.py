#!/usr/bin/env python3
import json,statistics,subprocess
def trials(cmd):
    return [json.loads(subprocess.check_output(cmd,text=True)) for _ in range(5)]
s=trials([".verify/native-highlight-benchmark"])
n=trials(["node","Benchmarks/highlightjs.cjs"])
sr=statistics.median(x["total_mb_per_second"] for x in s)
nr=statistics.median(x["total_mb_per_second"] for x in n)
print(json.dumps({
 "swift_total_mb_per_second":sr,"highlightjs_total_mb_per_second":nr,
 "swift_over_highlightjs":sr/nr,
 "swift_peak_rss_mb":statistics.median(x["peak_rss_kb"] for x in s)/1024,
 "highlightjs_peak_rss_mb":statistics.median(x["peak_rss_kb"] for x in n)/1024,
 "swift_memory_reduction_percent":100*(1-
   statistics.median(x["peak_rss_kb"] for x in s)/
   statistics.median(x["peak_rss_kb"] for x in n)),
 "workloads":[{
  "name":s[0]["workloads"][i]["name"],
  "swift_mb_per_second":statistics.median(x["workloads"][i]["mb_per_second"] for x in s),
  "highlightjs_mb_per_second":statistics.median(x["workloads"][i]["mb_per_second"] for x in n)
 } for i in range(len(s[0]["workloads"]))]
},indent=2))
