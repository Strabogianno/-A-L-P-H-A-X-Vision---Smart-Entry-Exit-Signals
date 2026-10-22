// (c) AlphaX. Automated execution around the unchanged AlphaX Vision engine.
#property copyright "AlphaX"
#property version "1.00"
#property description "Closed-bar AlphaX Vision EA. Configure SL and enable trading explicitly."
#include "AlphaX_Vision_Core.mqh"
#include "AlphaX_Vision_TradePolicy.mqh"

enum AXE_SIZE { AXE_FIXED_LOTS=0, AXE_EQUITY_RISK=1 };
enum AXE_STOP { AXE_STOP_POINTS=0, AXE_STOP_ATR=1 };
enum AXE_TARGET { AXE_SIGNAL_EXITS=0, AXE_TARGET_POINTS=1, AXE_TARGET_RISK_MULTIPLE=2 };

input group "Execution - approved starting controls"
input bool InpEnableTrading=false;              // Master switch: false = calculation/monitor only
input bool InpAllowRealAccount=false;           // Separately allow execution on a real account
input string InpRequiredSymbol="XAUUSD.cy";     // Exact symbol, or empty to allow another chart symbol
input ENUM_TIMEFRAMES InpSignalTimeframe=PERIOD_M1; // Attach to the same chart timeframe
input ulong InpMagicNumber=260102201;            // Unique EA ownership identifier
input bool InpAllowLong=true;
input bool InpAllowShort=true;
input bool InpCloseOnExitSignal=true;
input bool InpCloseOnOppositeTrend=true;         // Close remaining position when trend opposes it
input int InpMaxEntryDelaySeconds=30;            // Skip entries arriving later in the new candle
input int InpMaxSpreadPoints=0;                 // 0 = off; MT5 points, not pips or dollars
input int InpDeviationPoints=20;                // Requested execution deviation; broker-dependent
input int InpExitRetrySeconds=5;                // Retry a failed close on later ticks
input bool InpResetUncertainEntry=false;         // Recovery only after checking broker positions/orders/history

input group "Position size and protection"
input AXE_SIZE InpSizeMode=AXE_FIXED_LOTS;
input double InpFixedLots=0.01;
input double InpEquityRiskPercent=1.0;           // Used only in equity-risk mode; excludes costs/slippage
input AXE_STOP InpStopMode=AXE_STOP_POINTS;
input double InpStopLossPoints=0;               // REQUIRED in points mode before enabling entries
input double InpStopAtrMultiplier=2.0;          // Used only if ATR stop mode is explicitly selected
input AXE_TARGET InpTargetMode=AXE_SIGNAL_EXITS;
input double InpTakeProfitPoints=0;             // Required only for points target mode
input double InpTargetRiskMultiple=2.0;         // Used only for risk-multiple target mode

input group "Fusion System - published Gold M1 profile"
input int InpFusionLength=40;
input int InpSlowSensitivity=12;
input int InpFastSensitivity=5;
input group "EMA Settings"
input int InpEmaFastLength=21;
input int InpEmaMediumLength=55;
input int InpEmaSlowLength=200;
input group "AlphaX Pro Settings"
input int InpFastWprPeriod=11;
input int InpSlowWprPeriod=48;
input int InpTurtleWprPeriod=180;
input int InpOversold=-90;
input int InpOverbought=-10;
input int InpTrendLookback=25;
input double InpMinConfidence=35;
input bool InpEnableTrendGate=true;
input bool InpStrictGate=true;
input double InpUptrendTurtle=-35;
input double InpUptrendSlow=-40;
input double InpDowntrendTurtle=-65;
input double InpDowntrendSlow=-60;
input bool InpRequireRecovery=true;
input int InpRecoveryBars=3;
input double InpRecoveryMove=6;
input int InpCooldown=25;
input group "Date Filter - UTC, entries and indicator exits"
input bool InpEnableDateFilter=false;
input datetime InpStartDate=D'2026.03.20 00:00';
input datetime InpEndDate=D'2026.03.21 23:59';
input group "Feed alignment"
input AX_VOLUME InpVolume=AX_TICK_VOLUME;
input AX_CLOCK InpBrokerClock=AX_US_DST;
input int InpWinterUtcOffsetMinutes=120;
input AX_ANCHOR InpVwapAnchor=AX_BROKER_MIDNIGHT;
input int InpVwapUtcStartHour=0;
input int InpVwapUtcStartMinute=0;
input datetime InpCalculationStartUTC=0;          // 0 = all available calculation history
input group "History and display"
input int InpHistoryBars=0;                      // Initial warm-up cap; 0 = available chart history
input bool InpShowStatus=true;

CAlphaXEngine Engine;
MqlRates Rates[];
AXConfig Config;
bool warmed=false,uncertainEntry=false,stateReady=false;
int stateFile=INVALID_HANDLE,pendingExits=0;
datetime lastClosed=0,lastCurrentOpen=0,lastEntryAttemptBar=0,lastCloseAttempt=0;
long firstSeriesDate=0;
string statusText="Initializing",statusObject="",stateName="";
const int STATE_VERSION=1001;

bool Range(double value,double lower,double upper)
{ return AXEFinite(value)&&value>=lower&&value<=upper; }
uint HashText(string value)
{
 uint hash=2166136261;
 for(int i=0;i<StringLen(value);i++) { hash^=(uint)StringGetCharacter(value,i); hash*=16777619; }
 return hash;
}
bool ValidInputs(void)
{
 return Range(InpFusionLength,7,200)&&Range(InpSlowSensitivity,3,20)&&Range(InpFastSensitivity,2,15)&&
  Range(InpEmaFastLength,1,500)&&Range(InpEmaMediumLength,1,500)&&Range(InpEmaSlowLength,1,500)&&
  Range(InpFastWprPeriod,3,24)&&Range(InpSlowWprPeriod,15,60)&&Range(InpTurtleWprPeriod,100,500)&&
  Range(InpOversold,-99,-70)&&Range(InpOverbought,-30,-1)&&Range(InpTrendLookback,10,50)&&
  Range(InpMinConfidence,0,100)&&Range(InpUptrendTurtle,-50,-10)&&Range(InpUptrendSlow,-60,-20)&&
  Range(InpDowntrendTurtle,-90,-50)&&Range(InpDowntrendSlow,-80,-40)&&Range(InpRecoveryBars,2,10)&&
  Range(InpRecoveryMove,2,20)&&Range(InpCooldown,1,50)&&Range(InpWinterUtcOffsetMinutes,-840,840)&&
  Range(InpVwapUtcStartHour,0,23)&&Range(InpVwapUtcStartMinute,0,59)&&
  (!InpEnableDateFilter||InpStartDate<=InpEndDate)&&InpMagicNumber>0&&InpFixedLots>0&&AXEFinite(InpFixedLots)&&
  Range(InpEquityRiskPercent,0.001,100)&&Range(InpStopLossPoints,0,1e9)&&Range(InpStopAtrMultiplier,0.01,1000)&&
  Range(InpTakeProfitPoints,0,1e9)&&Range(InpTargetRiskMultiple,0.01,1000)&&
  InpMaxEntryDelaySeconds>=0&&InpMaxSpreadPoints>=0&&InpDeviationPoints>=0&&InpExitRetrySeconds>=1&&
  Range((int)InpSizeMode,0,1)&&Range((int)InpStopMode,0,1)&&Range((int)InpTargetMode,0,2)&&
  Range((int)InpVolume,0,1)&&Range((int)InpBrokerClock,0,2)&&Range((int)InpVwapAnchor,0,2)&&
  (InpHistoryBars==0||InpHistoryBars>=600)&&
  (InpRequiredSymbol==""||_Symbol==InpRequiredSymbol)&&_Period==InpSignalTimeframe;
}
void SetConfig(void)
{
 AXDefaults(Config);
 Config.fusionLength=InpFusionLength; Config.slowSensitivity=InpSlowSensitivity; Config.fastSensitivity=InpFastSensitivity;
 Config.emaFastLength=InpEmaFastLength; Config.emaMediumLength=InpEmaMediumLength; Config.emaSlowLength=InpEmaSlowLength;
 Config.fastWprPeriod=InpFastWprPeriod; Config.slowWprPeriod=InpSlowWprPeriod; Config.turtleWprPeriod=InpTurtleWprPeriod;
 Config.oversold=InpOversold; Config.overbought=InpOverbought; Config.trendLookback=InpTrendLookback;
 Config.minConfidence=InpMinConfidence; Config.enableTrendGate=InpEnableTrendGate; Config.strictGate=InpStrictGate;
 Config.upTurtle=InpUptrendTurtle; Config.upSlow=InpUptrendSlow; Config.downTurtle=InpDowntrendTurtle; Config.downSlow=InpDowntrendSlow;
 Config.requireRecovery=InpRequireRecovery; Config.recoveryBars=InpRecoveryBars; Config.recoveryMove=InpRecoveryMove;
 Config.cooldown=InpCooldown; Config.dateFilter=InpEnableDateFilter; Config.startDate=InpStartDate; Config.endDate=InpEndDate;
 Config.volumeSource=InpVolume; Config.brokerClock=InpBrokerClock; Config.winterOffsetMinutes=InpWinterUtcOffsetMinutes;
 Config.vwapAnchor=InpVwapAnchor; Config.sessionStartMinutes=InpVwapUtcStartHour*60+InpVwapUtcStartMinute;
 Engine.Configure(Config);
}
void Status(string value,bool writeLog=false)
{
 if(writeLog&&value!=statusText) Print("AlphaX EA: ",value);
 statusText=value;
}
bool SaveState(void)
{
 if(stateFile==INVALID_HANDLE) return !InpEnableTrading;
 ResetLastError();
 if(!FileSeek(stateFile,0,SEEK_SET)) return false;
 uint wrote=FileWriteInteger(stateFile,STATE_VERSION);
 wrote+=FileWriteLong(stateFile,(long)lastEntryAttemptBar);
 wrote+=FileWriteInteger(stateFile,pendingExits);
 wrote+=FileWriteInteger(stateFile,uncertainEntry?1:0);
 FileFlush(stateFile);
 bool ok=wrote==20&&GetLastError()==0;
 if(!ok) Status("State persistence failed; entries blocked",true);
 return ok;
}
bool OpenState(void)
{
 string identity=AccountInfoString(ACCOUNT_SERVER)+"|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+_Symbol+"|"+(string)InpMagicNumber;
 stateName="AXVisionEA_"+StringFormat("%08X",HashText(identity))+".bin";
 // No sharing flags: one trading instance for this account/symbol/magic.
 // Tester files remain local to the testing agent, not the shared live folder.
 int flags=FILE_READ|FILE_WRITE|FILE_BIN;
 if(!MQLInfoInteger(MQL_TESTER)) flags|=FILE_COMMON;
 stateFile=FileOpen(stateName,flags);
 if(stateFile==INVALID_HANDLE) { Status("Cannot acquire state lock; check another EA instance with the same magic",true); return false; }
 // Every Strategy Tester pass starts clean; live/demo restarts retain state.
 if(!MQLInfoInteger(MQL_TESTER)&&FileSize(stateFile)>0)
 {
  if(FileSize(stateFile)<20) { Status("State file is incomplete; execution initialization stopped",true); return false; }
  int version=FileReadInteger(stateFile);
  if(version==STATE_VERSION)
  {
   lastEntryAttemptBar=(datetime)FileReadLong(stateFile); pendingExits=FileReadInteger(stateFile);
   uncertainEntry=FileReadInteger(stateFile)!=0;
  }
  else { Status("Unknown state-file version; execution initialization stopped",true); return false; }
 }
 if(InpResetUncertainEntry) { uncertainEntry=false; Print("AlphaX EA: uncertain-entry latch manually reset by input."); }
 stateReady=true;
 return SaveState();
}
bool ExecutionAllowed(void)
{
 bool tester=(bool)MQLInfoInteger(MQL_TESTER);
 bool realAccount=AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL;
 if(AXEExecutionPermission(InpEnableTrading,tester,realAccount,InpAllowRealAccount,
   (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED),(bool)MQLInfoInteger(MQL_TRADE_ALLOWED),
   (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED),(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT),
   (bool)TerminalInfoInteger(TERMINAL_CONNECTED))) return true;
 if(!InpEnableTrading) return false;
 if(realAccount&&!InpAllowRealAccount)
 { Status("Real-account execution is disabled",true); return false; }
 if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED)||
    !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)||!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
 { Status("Execution permission is off in MT5/account/EA settings",true); return false; }
 if(!MQLInfoInteger(MQL_TESTER)&&!TerminalInfoInteger(TERMINAL_CONNECTED))
 { Status("Terminal disconnected; awaiting fresh quotes",true); return false; }
 return false;
}
bool Netting(void) { return AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; }
bool SelectedPositionOwned(void)
{
 if(PositionGetString(POSITION_SYMBOL)!=_Symbol||(ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) return false;
 if(!Netting()) return true;
 // A netted position can contain deals from several strategies, even if its
 // current POSITION_MAGIC happens to match this EA.
 long identifier=PositionGetInteger(POSITION_IDENTIFIER);
 if(!HistorySelectByPosition(identifier)) return false;
 int deals=HistoryDealsTotal(); if(deals==0) return false;
 for(int i=0;i<deals;i++)
 {
  ulong ticket=HistoryDealGetTicket(i); if(ticket==0) return false;
  long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
  if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL) continue;
  if((ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)==InpMagicNumber) continue;
  long reason=HistoryDealGetInteger(ticket,DEAL_REASON);
  if(reason!=DEAL_REASON_SL&&reason!=DEAL_REASON_TP&&reason!=DEAL_REASON_SO) return false;
 }
 return true;
}
void Exposure(int &own,int &foreign,int &orders,int &ownSideMask)
{
 own=0; foreign=0; orders=0; ownSideMask=0;
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
  ulong ticket=PositionGetTicket(i); if(ticket==0||PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
  if(SelectedPositionOwned())
  { own++; ownSideMask|=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:2; }
  else foreign++;
 }
 for(int i=OrdersTotal()-1;i>=0;i--)
 {
  ulong ticket=OrderGetTicket(i);
  if(ticket>0&&OrderGetString(ORDER_SYMBOL)==_Symbol) orders++;
 }
}
int UnprotectedPositionMask(void)
{
 int mask=0;
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
  if(PositionGetTicket(i)==0||!SelectedPositionOwned()) continue;
  if(PositionGetDouble(POSITION_SL)<=0) mask|=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:2;
 }
 return mask;
}
bool Filling(ENUM_ORDER_TYPE_FILLING &fill)
{
 long allowed=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
 if((allowed&SYMBOL_FILLING_FOK)!=0) { fill=ORDER_FILLING_FOK; return true; }
 if((allowed&SYMBOL_FILLING_IOC)!=0) { fill=ORDER_FILLING_IOC; return true; }
 Status("Symbol has no FOK/IOC filling mode; market execution unavailable",true); return false;
}
bool TickQuote(MqlTick &tick)
{ return SymbolInfoTick(_Symbol,tick)&&tick.bid>0&&tick.ask>=tick.bid; }
bool HasStopConfiguration(void)
{ return InpStopMode==AXE_STOP_ATR?InpStopAtrMultiplier>0:InpStopLossPoints>0; }
bool BuildProtection(int side,const AXBar &bar,const MqlTick &tick,double &entry,double &sl,double &tp)
{
 double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT),grid=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
 double distance=AXEStopDistance((int)InpStopMode,InpStopLossPoints,point,AXValid(bar.atr)?bar.atr:0,InpStopAtrMultiplier);
 if(distance<=0) { Status("Configure a positive stop loss before enabling entries",true); return false; }
 entry=side==1?tick.ask:tick.bid;
 sl=AXEPriceGrid(entry-side*distance,grid,-side); tp=0;
 if(InpTargetMode==AXE_TARGET_POINTS)
 {
  if(InpTakeProfitPoints<=0) { Status("Points target requires positive take-profit distance",true); return false; }
  tp=AXEPriceGrid(entry+side*InpTakeProfitPoints*point,grid,side);
 }
 else if(InpTargetMode==AXE_TARGET_RISK_MULTIPLE)
  tp=AXEPriceGrid(entry+side*MathAbs(entry-sl)*InpTargetRiskMultiple,grid,side);
 int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
 sl=NormalizeDouble(sl,digits); if(tp>0) tp=NormalizeDouble(tp,digits);
 double minimum=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
 if(!AXEProtectionValid(side,entry,tick.bid,tick.ask,sl,tp,minimum,grid))
 { Status("Configured SL/TP is invalid for current quote/broker minimum; entry skipped",true); return false; }
 return true;
}
double LotsForTrade(int side,double entry,double sl)
{
 double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
 double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),raw=InpFixedLots;
 if(InpSizeMode==AXE_EQUITY_RISK)
 {
  double unitLoss=0;
  if(!OrderCalcProfit(side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,1.0,entry,sl,unitLoss)||unitLoss>=0) return 0;
  raw=AccountInfoDouble(ACCOUNT_EQUITY)*(InpEquityRiskPercent/100.0)/MathAbs(unitLoss);
 }
 if(InpSizeMode==AXE_FIXED_LOTS&&raw>maximum) return 0;
 double lots=NormalizeDouble(AXEVolumeFloor(raw,minimum,maximum,step),8);
 double limit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
 if(limit>0&&lots>limit) return 0;
 return lots;
}
void OpenTrade(int side,datetime signalBar,const AXBar &bar)
{
 int own,foreign,orders,sides; Exposure(own,foreign,orders,sides);
 if(!AXEEntryAllowed(ExecutionAllowed(),own>0,foreign>0,orders>0,uncertainEntry,
      AXEFreshBar((long)TimeCurrent(),(long)lastCurrentOpen,InpMaxEntryDelaySeconds),side,InpAllowLong,InpAllowShort)) return;
 if(pendingExits!=0||signalBar<=lastEntryAttemptBar) return;
 MqlTick tick; if(!TickQuote(tick)) return;
 double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
 if(point<=0) return;
 if(InpMaxSpreadPoints>0&&(tick.ask-tick.bid)/point>InpMaxSpreadPoints)
 { Status("Entry skipped: spread filter",true); return; }
 long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
 if(mode==SYMBOL_TRADE_MODE_DISABLED||mode==SYMBOL_TRADE_MODE_CLOSEONLY||
    (side==1&&mode==SYMBOL_TRADE_MODE_SHORTONLY)||(side==-1&&mode==SYMBOL_TRADE_MODE_LONGONLY))
 { Status("Entry direction is unavailable on this symbol",true); return; }
 long orderModes=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
 if((orderModes&SYMBOL_ORDER_MARKET)==0||(orderModes&SYMBOL_ORDER_SL)==0)
 { Status("Broker symbol does not support market orders with stop loss",true); return; }
 double entry,sl,tp; if(!BuildProtection(side,bar,tick,entry,sl,tp)) return;
 if(tp>0&&(orderModes&SYMBOL_ORDER_TP)==0) return;
 double lots=LotsForTrade(side,entry,sl);
 if(lots<=0) { Status("Entry skipped: size below minimum, invalid volume, or risk calculation unavailable",true); return; }
 MqlTradeRequest request={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
 request.action=TRADE_ACTION_DEAL; request.magic=InpMagicNumber; request.symbol=_Symbol;
 request.type=side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL; request.volume=lots; request.price=entry;
 request.sl=sl; request.tp=tp; request.deviation=InpDeviationPoints;
 request.comment="AXV "+(side==1?"L ":"S ")+(string)(long)signalBar;
 if(!Filling(request.type_filling)) return;
 bool checked=OrderCheck(request,check);
 if(!AXEPreflightAccepted(checked,(int)check.retcode))
 { Status("Entry preflight rejected: "+(string)check.retcode+" "+check.comment,true); return; }
 // Consume before submission. An ambiguous response is never retried blindly.
 lastEntryAttemptBar=signalBar; uncertainEntry=true;
 if(!SaveState()) return;
 bool sent=OrderSend(request,result);
 bool filled=sent&&(result.retcode==TRADE_RETCODE_DONE||result.retcode==TRADE_RETCODE_DONE_PARTIAL);
 bool ambiguous=result.retcode==TRADE_RETCODE_TIMEOUT||result.retcode==TRADE_RETCODE_CONNECTION||
                result.retcode==TRADE_RETCODE_PLACED||result.retcode==0;
 if(filled||!ambiguous) uncertainEntry=false;
 SaveState();
 Status(filled?"Entry executed; broker SL requested with order":
       uncertainEntry?"Entry result uncertain: new entries locked; check broker history":
       "Entry rejected: "+(string)result.retcode+" "+result.comment,true);
}
void RetryCloses(void)
{
 if(pendingExits==0||!ExecutionAllowed()) return;
 if(TimeCurrent()-lastCloseAttempt<InpExitRetrySeconds) return;
 MqlTick tick; if(!TickQuote(tick)) return;
 lastCloseAttempt=TimeCurrent();
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
  ulong ticket=PositionGetTicket(i);
  if(ticket==0||!SelectedPositionOwned()) continue;
  int side=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
  if((pendingExits&(side==1?1:2))==0) continue;
  MqlTradeRequest request={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
  request.action=TRADE_ACTION_DEAL; request.position=ticket; request.symbol=_Symbol; request.magic=InpMagicNumber;
  request.type=side==1?ORDER_TYPE_SELL:ORDER_TYPE_BUY; request.volume=PositionGetDouble(POSITION_VOLUME);
  request.price=side==1?tick.bid:tick.ask; request.deviation=InpDeviationPoints; request.comment="AXV signal exit";
  if(!Filling(request.type_filling)) continue;
  bool checked=OrderCheck(request,check);
  if(!AXEPreflightAccepted(checked,(int)check.retcode))
  { Status("Close preflight rejected; will retry: "+(string)check.retcode+" "+check.comment,true); continue; }
  bool sent=OrderSend(request,result);
  Status(sent&&result.retcode==TRADE_RETCODE_DONE?"Close executed":
     "Close pending/rejected; will reconcile and retry: "+(string)result.retcode+" "+result.comment,true);
 }
 int own,foreign,orders,sides; Exposure(own,foreign,orders,sides);
 pendingExits&=sides; SaveState();
}
int ExitMask(const AXBar &bar)
{
 int mask=0;
 if(AXEExitRequired(1,bar.longExit,bar.shortExit,bar.currentTrend,InpCloseOnExitSignal,InpCloseOnOppositeTrend)) mask|=1;
 if(AXEExitRequired(-1,bar.longExit,bar.shortExit,bar.currentTrend,InpCloseOnExitSignal,InpCloseOnOppositeTrend)) mask|=2;
 return mask;
}
bool Rebuild(void)
{
 int available=Bars(_Symbol,InpSignalTimeframe);
 int wanted=InpHistoryBars>0?MathMin(available,InpHistoryBars):available;
 int minimum=MathMax(200,MathMax(InpFusionLength,InpTurtleWprPeriod))+InpTrendLookback+20;
 if(wanted<minimum+1) { Status("Waiting for enough price history"); return false; }
 MqlRates all[]; ArraySetAsSeries(all,false);
 int copied=CopyRates(_Symbol,InpSignalTimeframe,0,wanted,all);
 if(copied!=wanted) { Status("Waiting for history synchronization"); return false; }
 int start=0;
 if(InpCalculationStartUTC>0)
  while(start<copied-1&&AXToUTC(all[start].time,Config)<InpCalculationStartUTC) start++;
 int count=copied-1-start;
 if(count<minimum) { Status("Calculation start leaves insufficient warm-up history"); return false; }
 ArrayResize(Rates,count,2048); ArrayCopy(Rates,all,0,start,count);
 Engine.Configure(Config); Engine.Resize(count);
 for(int i=0;i<count;i++) Engine.Step(Rates,i);
 firstSeriesDate=SeriesInfoInteger(_Symbol,InpSignalTimeframe,SERIES_FIRSTDATE);
 lastClosed=Rates[count-1].time; lastCurrentOpen=all[copied-1].time; warmed=true;
 return true;
}
bool UpdateSignals(AXBar &latest,int &exitMask,bool &entryEligible)
{
 exitMask=0; entryEligible=false;
 if(!warmed)
 {
  if(!Rebuild()) return false;
  latest=Engine.v[ArraySize(Rates)-1]; exitMask=ExitMask(latest);
  Status("Warm-up complete; waiting for a new closed-candle entry",true); return true;
 }
 datetime current=iTime(_Symbol,InpSignalTimeframe,0);
 if(current==0||current==lastCurrentOpen) return false;
 // Deeper history changes initialization. A normal rolling chart boundary
 // moving forward does not invalidate our already computed cached state.
 long earliest=SeriesInfoInteger(_Symbol,InpSignalTimeframe,SERIES_FIRSTDATE);
 if(earliest<firstSeriesDate)
 {
  if(!Rebuild()) return false;
  latest=Engine.v[ArraySize(Rates)-1]; exitMask=ExitMask(latest);
  Status("History boundary changed; rebuilt and suppressed retrospective entry",true); return true;
 }
 firstSeriesDate=earliest;
 MqlRates extra[]; ArraySetAsSeries(extra,false);
 int copied=CopyRates(_Symbol,InpSignalTimeframe,lastClosed,current,extra);
 if(copied<2||extra[0].time!=lastClosed||extra[copied-1].time!=current)
 { warmed=false; Status("History gap; waiting to rebuild",true); return false; }
 int n=ArraySize(Rates);
 // A corrected previously closed candle changes recursive calculations.
 if(extra[0].open!=Rates[n-1].open||extra[0].high!=Rates[n-1].high||extra[0].low!=Rates[n-1].low||
    extra[0].close!=Rates[n-1].close||extra[0].tick_volume!=Rates[n-1].tick_volume||extra[0].real_volume!=Rates[n-1].real_volume)
 {
  warmed=false; if(!Rebuild()) return false;
  latest=Engine.v[ArraySize(Rates)-1]; exitMask=ExitMask(latest);
  Status("Corrected history; rebuilt and suppressed retrospective entry",true); return true;
 }
 int added=copied-2;
 if(added<1) return false;
 ArrayResize(Rates,n+added,2048); Engine.Resize(n+added);
 for(int j=1;j<copied-1;j++)
 {
  int index=n+j-1; Rates[index]=extra[j]; Engine.Step(Rates,index); exitMask|=ExitMask(Engine.v[index]);
 }
 latest=Engine.v[ArraySize(Rates)-1]; lastClosed=Rates[ArraySize(Rates)-1].time; lastCurrentOpen=current;
 entryEligible=true; return true;
}
void DrawStatus(void)
{
 if(!InpShowStatus) return;
 if(ObjectFind(0,statusObject)<0)
 {
  ObjectCreate(0,statusObject,OBJ_LABEL,0,0,0); ObjectSetInteger(0,statusObject,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  ObjectSetInteger(0,statusObject,OBJPROP_XDISTANCE,12); ObjectSetInteger(0,statusObject,OBJPROP_YDISTANCE,25);
  ObjectSetInteger(0,statusObject,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,statusObject,OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,statusObject,OBJPROP_HIDDEN,true); ObjectSetString(0,statusObject,OBJPROP_FONT,"Arial");
 }
 string mode=InpEnableTrading?"TRADING REQUESTED":"MONITOR ONLY";
 if(InpEnableTrading&&!MQLInfoInteger(MQL_TESTER)&&(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED))) mode+=" | MT5 ALGO OFF";
 if(InpEnableTrading&&!MQLInfoInteger(MQL_TESTER)&&AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL&&!InpAllowRealAccount)
  mode+=" | REAL ACCOUNT BLOCKED";
 if(!HasStopConfiguration()) mode+=" | STOP LOSS NOT CONFIGURED";
 if(uncertainEntry) mode+=" | ENTRY LOCKED";
 string text="AlphaX Vision EA | "+_Symbol+" "+EnumToString(InpSignalTimeframe)+" | "+mode+" | "+statusText;
 ObjectSetString(0,statusObject,OBJPROP_TEXT,text);
 ObjectSetInteger(0,statusObject,OBJPROP_COLOR,InpEnableTrading&&HasStopConfiguration()?clrLimeGreen:clrOrange);
}
int OnInit(void)
{
 if(!ValidInputs())
 { Print("AlphaX EA: invalid settings, wrong required symbol or chart timeframe. Use XAUUSD.cy / M1 for the supplied preset."); return INIT_PARAMETERS_INCORRECT; }
 SetConfig(); statusObject="AXVEA_Status_"+(string)ChartID()+"_"+(string)GetMicrosecondCount();
 if(InpEnableTrading&&!OpenState()) return INIT_FAILED;
 Status(!InpEnableTrading?"Monitoring; execution switch is off":!HasStopConfiguration()?"Set Stop Loss Points or explicitly choose ATR stop mode":"Waiting for market data",true);
 EventSetTimer(1); DrawStatus(); return INIT_SUCCEEDED;
}
void OnTick(void)
{
 AXBar bar; AXEmpty(bar); int exitMask=0; bool eligible=false;
 bool changed=UpdateSignals(bar,exitMask,eligible);
 if(InpEnableTrading)
 {
  int own,foreign,orders,sides; Exposure(own,foreign,orders,sides);
  int before=pendingExits;
  pendingExits&=sides; // Never carry an old exit into a newly opened position.
  if(changed) pendingExits|=exitMask&sides;
  int unprotected=UnprotectedPositionMask();
  if(unprotected!=0) { pendingExits|=unprotected; Status("Owned position has no broker stop; requesting protective close",true); }
  if(before!=pendingExits) SaveState();
  RetryCloses(); // Spread, date and sizing filters never prevent a requested exit.
  // Do not submit a new entry on the same tick that began with our position.
  // This also avoids opening against a close whose server updates are pending.
  if(changed&&eligible&&own==0)
  {
   int side=AXEEntryDirection(bar.longEntry,bar.shortEntry);
   if(side!=0) OpenTrade(side,lastClosed,bar);
  }
 }
 DrawStatus();
}
void OnTimer(void) { DrawStatus(); }
void OnDeinit(const int reason)
{
 EventKillTimer();
 if(stateFile!=INVALID_HANDLE) { if(stateReady) SaveState(); FileClose(stateFile); stateFile=INVALID_HANDLE; }
 if(statusObject!="") ObjectDelete(0,statusObject);
}
