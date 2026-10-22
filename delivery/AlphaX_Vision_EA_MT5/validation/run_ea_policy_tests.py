"""Run the actual pure MQL rule bodies through the installed .NET C# compiler.

Only function modifiers and built-in math names are adapted; formulas and test
cases are shared with the MQL5 test script. This does not emulate a broker,
execute MQL5 bytecode, validate the signal engine, or prove MT5 trade execution.
"""
from pathlib import Path
import re
import subprocess
import json

root = Path(__file__).resolve().parents[1]
compiler = Path(r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe")
if not compiler.exists():
    raise SystemExit("Installed .NET C# compiler not found; run AlphaX_Vision_EA_PolicyTest.mq5 inside MT5 instead")
policy = (root / "AlphaX_Vision_TradePolicy.mqh").read_text(encoding="utf-8-sig")
cases = (root / "validation/AlphaX_Vision_PolicyCases.mqh").read_text(encoding="utf-8-sig")
shared = policy + "\n" + cases
shared = re.sub(r"^#.*$", "", shared, flags=re.M)
shared = re.sub(r"^(bool|int|double|void)\s+(\w+)\(", r"public static \1 \2(", shared, flags=re.M)
for old, new in {"MathFloor": "Math.Floor", "MathCeil": "Math.Ceiling", "MathMin": "Math.Min", "MathMax": "Math.Max"}.items():
    shared = shared.replace(old, new)
header = """using System;
public class AlphaXPolicyTests {
static int passed=0,failed=0;
static bool Near(double a,double b) { return Math.Abs(a-b)<1e-8; }
static void Check(bool value,string label) {
 if(value) passed++; else { failed++; Console.WriteLine("FAIL: "+label); }
}
"""
footer = """
public static int Main() {
 RunPolicyCases();
 Console.WriteLine("passed="+passed+" failed="+failed);
 return failed==0?0:1;
}
}
"""
build = root / "build"
build.mkdir(exist_ok=True)
source = build / "AlphaXPolicyTests.cs"
binary = build / "AlphaXPolicyTests.exe"
source.write_text(header + shared + footer, encoding="utf-8")
compile_result = subprocess.run([str(compiler), "/nologo", "/warnaserror", "/optimize+", "/out:"+str(binary), str(source)], capture_output=True, text=True)
if compile_result.returncode:
    raise SystemExit(compile_result.stdout + compile_result.stderr)
result = subprocess.run([str(binary)], capture_output=True, text=True)
summary = {"test": "shared-source execution policy", "runtime": ".NET (not MT5)",
           "passed": result.returncode == 0, "output": result.stdout.strip(), "stderr": result.stderr.strip()}
(build / "ea_policy_tests.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary, indent=2))
raise SystemExit(result.returncode)
