#property version "1.00"
#include "..\AlphaX_Vision_TradePolicy.mqh"
int passed=0,failed=0;
bool Near(double a,double b) { return MathAbs(a-b)<1.0e-8; }
void Check(bool value,string label)
{ if(value) passed++; else { failed++; Print("FAIL: ",label); } }
#include "AlphaX_Vision_PolicyCases.mqh"
void OnStart()
{
 RunPolicyCases();
 Print("AlphaX EA pure execution-policy checks: ",passed," passed; ",failed," failed.");
}
