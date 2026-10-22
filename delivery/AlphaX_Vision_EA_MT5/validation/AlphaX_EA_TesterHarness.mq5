#property version "1.00"
#include "..\AlphaX_Vision_TradePolicy.mqh"
int passed=0,failed=0;
bool Near(double a,double b) { return MathAbs(a-b)<1.0e-8; }
void Check(bool value,string label) { if(value) passed++; else { failed++; Print("FAIL: ",label); } }
#include "AlphaX_Vision_PolicyCases.mqh"
int OnInit()
{
 RunPolicyCases();
 int f=FileOpen("AlphaX_EA_MT5_policy_result.txt",FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
 if(f!=INVALID_HANDLE) { FileWrite(f,"passed="+(string)passed+" failed="+(string)failed); FileClose(f); }
 Print("AlphaX EA MT5 policy harness: passed=",passed," failed=",failed);
 return failed==0?INIT_SUCCEEDED:INIT_FAILED;
}
void OnTick() { TesterStop(); }
