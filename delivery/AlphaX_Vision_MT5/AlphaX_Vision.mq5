// (c) AlphaX. Port of the user-supplied Pine v6 source.
#property copyright "AlphaX"
#property version "1.00"
#property description "AlphaX Vision: native port preserving supplied Pine defaults and signal rules."
#property indicator_chart_window
#property indicator_buffers 38
#property indicator_plots 36

#include "AlphaX_Vision_Core.mqh"
#include "AlphaX_Vision_Render.mqh"

input group "Fusion System"
input int InpFusionLength=122;                  // Fusion MA Length [7..200]
input int InpSlowSensitivity=12;                // Fusion Slow Sensitivity [3..20]
input int InpFastSensitivity=5;                 // Fusion Fast Sensitivity [2..15]
input bool InpShowCloud=true;                   // Show Trend Cloud
input group "EMA Settings"
input bool InpShowEmaFast=true;                 // Show Fast EMA
input bool InpShowEmaMedium=true;               // Show Medium EMA
input bool InpShowEmaSlow=true;                 // Show Slow EMA
input int InpEmaFastLength=21;                  // Fast EMA Length [1..500]
input int InpEmaMediumLength=55;                // Medium EMA Length [1..500]
input int InpEmaSlowLength=120;                 // Slow EMA Length [1..500]
input group "AlphaX Pro Settings"
input int InpFastWprPeriod=21;                  // Fast WPR Period [3..24]
input int InpSlowWprPeriod=55;                  // Slow WPR Period [15..60]
input int InpTurtleWprPeriod=120;               // Turtle WPR Period [100..500]
input int InpOversold=-90;                     // Oversold Level [-99..-70]
input int InpOverbought=-10;                   // Overbought Level [-30..-1]
input int InpTrendLookback=20;                 // Trend Detection Period [10..50]
input double InpMinConfidence=14;              // Min Pro Confidence % [0..100]
input bool InpEnableTrendGate=true;            // Enable Trend Alignment Gate
input bool InpStrictGate=true;                 // Strict Mode (Stronger Filter)
input double InpUptrendTurtle=-35;             // Uptrend: Turtle WPR Above
input double InpUptrendSlow=-40;               // Uptrend: Slow WPR Above
input double InpDowntrendTurtle=-65;           // Downtrend: Turtle WPR Below
input double InpDowntrendSlow=-60;             // Downtrend: Slow WPR Below
input bool InpRequireRecovery=true;            // Require WPR Recovery (Counter-Trend)
input int InpRecoveryBars=3;                   // Recovery Lookback [2..10]
input double InpRecoveryMove=6;                // Minimum Recovery Move [2..20]
input group "Trend Filters"
input int InpCooldown=25;                      // Trend Label Cooldown [1..50]
input double InpAtrOffset=2.4;                 // Signal ATR Offset [0..10]
input AX_LABEL_SIZE InpLabelSize=AX_SIZE_SMALL; // Signal Label Size (Pine mapping)
input group "Date Filter - UTC"
input bool InpEnableDateFilter=false;          // Enable Date Filter (entries/exits only)
input datetime InpStartDate=D'2026.03.20 00:00';
input datetime InpEndDate=D'2026.03.21 23:59';
input group "Theme"
input color InpBullPrimary=C'200,230,36';
input color InpBullBright=C'212,240,58';
input color InpBullDim=C'154,184,28';
input color InpBearPrimary=C'255,23,68';
input color InpBearBright=C'255,82,82';
input color InpBearDim=C'213,0,50';
input color InpNeutral=C'85,85,85';
input color InpEmaFastColor=C'200,230,36';
input color InpEmaMediumColor=C'136,136,136';
input color InpEmaSlowColor=C'85,85,85';
input group "MT5 Data Alignment - match the TradingView feed"
input AX_VOLUME InpVolume=AX_TICK_VOLUME;       // Explicit volume source, no automatic substitution
input AX_CLOCK InpBrokerClock=AX_FIXED_OFFSET; // Broker server DST policy
input int InpWinterUtcOffsetMinutes=120;       // Server minus UTC in winter; fixed mode uses this year round
input AX_ANCHOR InpVwapAnchor=AX_BROKER_MIDNIGHT; // VWAP reset rule
input int InpVwapUtcStartHour=0;                // UTC session start hour (UTC-session mode)
input int InpVwapUtcStartMinute=0;              // UTC session start minute
input group "MT5 Alerts"
input bool InpAlertTrendBull=true;
input bool InpAlertTrendBear=true;
input bool InpAlertLongEntry=true;
input bool InpAlertShortEntry=true;
input bool InpAlertLongExit=true;
input bool InpAlertShortExit=true;
input bool InpAlertAtBarClose=true;            // Alert delivery only; chart always recalculates live
input bool InpPopupAlerts=false;
input bool InpPushAlerts=false;
input bool InpEmailAlerts=false;
input group "Validation"
input bool InpExportCsv=false;                 // Export closed bars to MQL5/Files
input string InpExportName="AlphaX_Vision_comparison.csv"; // Use a unique filename per chart
input datetime InpCalculationStartUTC=0;       // Optional dataset start, separate from Date Filter

double BFast[],BMedium[],BSlow[],BFusionSlow[],BSlowColor[],BFusionFast[],BFastColor[];
double BTrendBull[],BTrendBear[],BLongEntry[],BShortEntry[],BLongExit[],BShortExit[];
double BBuyConfidence[],BSellConfidence[],BFastWpr[],BSlowWpr[],BTurtleWpr[],BTrend[];
double BRawFusion[],BVwap[],BRsi[],BRsiEma[],BMacd[],BMacdSignal[],BHist[],BStochK[],BStochD[],BAtr[];
double BBullScore[],BBearScore[],BCondition[],BHasEntry[],BEma50[],BEma200[],BVolumeStrength[],BUtc[],BSession[];
CAlphaXEngine Engine;
CAlphaXRenderer Renderer;
AXTheme Theme;
MqlRates Rates[];
bool initialized=false;
datetime firstTime=0,lastAlertTime=0,lastClosedAlert=0;
int lastAlertMask=0,calculationStart=-1,csvHandle=INVALID_HANDLE,csvWritten=0;

bool InRange(const double x,const double a,const double b) { return x>=a&&x<=b; }
bool ValidInputs(void)
{
 return InRange(InpFusionLength,7,200)&&InRange(InpSlowSensitivity,3,20)&&InRange(InpFastSensitivity,2,15)&&
  InRange(InpEmaFastLength,1,500)&&InRange(InpEmaMediumLength,1,500)&&InRange(InpEmaSlowLength,1,500)&&
  InRange(InpFastWprPeriod,3,24)&&InRange(InpSlowWprPeriod,15,60)&&InRange(InpTurtleWprPeriod,100,500)&&
  InRange(InpOversold,-99,-70)&&InRange(InpOverbought,-30,-1)&&InRange(InpTrendLookback,10,50)&&
  InRange(InpMinConfidence,0,100)&&InRange(InpUptrendTurtle,-50,-10)&&InRange(InpUptrendSlow,-60,-20)&&
  InRange(InpDowntrendTurtle,-90,-50)&&InRange(InpDowntrendSlow,-80,-40)&&InRange(InpRecoveryBars,2,10)&&
  InRange(InpRecoveryMove,2,20)&&InRange(InpCooldown,1,50)&&InRange(InpAtrOffset,0,10)&&
  InRange(InpWinterUtcOffsetMinutes,-840,840)&&InRange(InpVwapUtcStartHour,0,23)&&InRange(InpVwapUtcStartMinute,0,59)&&
  (!InpEnableDateFilter||InpStartDate<=InpEndDate)&&
  (!InpExportCsv||(StringLen(InpExportName)>0&&StringFind(InpExportName,"\\")<0&&StringFind(InpExportName,"/")<0));
}
void Configure(void)
{
 AXConfig c; AXDefaults(c);
 c.fusionLength=InpFusionLength; c.slowSensitivity=InpSlowSensitivity; c.fastSensitivity=InpFastSensitivity;
 c.emaFastLength=InpEmaFastLength; c.emaMediumLength=InpEmaMediumLength; c.emaSlowLength=InpEmaSlowLength;
 c.fastWprPeriod=InpFastWprPeriod; c.slowWprPeriod=InpSlowWprPeriod; c.turtleWprPeriod=InpTurtleWprPeriod;
 c.oversold=InpOversold; c.overbought=InpOverbought; c.trendLookback=InpTrendLookback; c.minConfidence=InpMinConfidence;
 c.enableTrendGate=InpEnableTrendGate; c.strictGate=InpStrictGate;
 c.upTurtle=InpUptrendTurtle; c.upSlow=InpUptrendSlow; c.downTurtle=InpDowntrendTurtle; c.downSlow=InpDowntrendSlow;
 c.requireRecovery=InpRequireRecovery; c.recoveryBars=InpRecoveryBars; c.recoveryMove=InpRecoveryMove;
 c.cooldown=InpCooldown; c.atrOffset=InpAtrOffset;
 c.dateFilter=InpEnableDateFilter; c.startDate=InpStartDate; c.endDate=InpEndDate;
 c.volumeSource=InpVolume; c.brokerClock=InpBrokerClock; c.winterOffsetMinutes=InpWinterUtcOffsetMinutes;
 c.vwapAnchor=InpVwapAnchor; c.sessionStartMinutes=InpVwapUtcStartHour*60+InpVwapUtcStartMinute;
 Engine.Configure(c);
 Theme.bull=InpBullPrimary; Theme.bullBright=InpBullBright; Theme.bullDim=InpBullDim;
 Theme.bear=InpBearPrimary; Theme.bearBright=InpBearBright; Theme.bearDim=InpBearDim;
 Theme.neutral=InpNeutral; Theme.emaFast=InpEmaFastColor; Theme.cloud=InpShowCloud;
 Theme.fastEma=InpShowEmaFast; Theme.size=InpLabelSize;
}
int OnInit(void)
{
 if(!ValidInputs()) { Print("AlphaX: input outside the original Pine ranges, invalid dates, or invalid export filename."); return INIT_PARAMETERS_INCORRECT; }
 Configure();
 SetIndexBuffer(0,BFast,INDICATOR_DATA); SetIndexBuffer(1,BMedium,INDICATOR_DATA); SetIndexBuffer(2,BSlow,INDICATOR_DATA);
 SetIndexBuffer(3,BFusionSlow,INDICATOR_DATA); SetIndexBuffer(4,BSlowColor,INDICATOR_COLOR_INDEX);
 SetIndexBuffer(5,BFusionFast,INDICATOR_DATA); SetIndexBuffer(6,BFastColor,INDICATOR_COLOR_INDEX);
 SetIndexBuffer(7,BTrendBull,INDICATOR_DATA); SetIndexBuffer(8,BTrendBear,INDICATOR_DATA);
 SetIndexBuffer(9,BLongEntry,INDICATOR_DATA); SetIndexBuffer(10,BShortEntry,INDICATOR_DATA);
 SetIndexBuffer(11,BLongExit,INDICATOR_DATA); SetIndexBuffer(12,BShortExit,INDICATOR_DATA);
 SetIndexBuffer(13,BBuyConfidence,INDICATOR_DATA); SetIndexBuffer(14,BSellConfidence,INDICATOR_DATA);
 SetIndexBuffer(15,BFastWpr,INDICATOR_DATA); SetIndexBuffer(16,BSlowWpr,INDICATOR_DATA); SetIndexBuffer(17,BTurtleWpr,INDICATOR_DATA);
 SetIndexBuffer(18,BTrend,INDICATOR_DATA); SetIndexBuffer(19,BRawFusion,INDICATOR_DATA); SetIndexBuffer(20,BVwap,INDICATOR_DATA);
 SetIndexBuffer(21,BRsi,INDICATOR_DATA); SetIndexBuffer(22,BRsiEma,INDICATOR_DATA); SetIndexBuffer(23,BMacd,INDICATOR_DATA);
 SetIndexBuffer(24,BMacdSignal,INDICATOR_DATA); SetIndexBuffer(25,BHist,INDICATOR_DATA); SetIndexBuffer(26,BStochK,INDICATOR_DATA);
 SetIndexBuffer(27,BStochD,INDICATOR_DATA); SetIndexBuffer(28,BAtr,INDICATOR_DATA);
 SetIndexBuffer(29,BBullScore,INDICATOR_DATA); SetIndexBuffer(30,BBearScore,INDICATOR_DATA);
 SetIndexBuffer(31,BCondition,INDICATOR_DATA); SetIndexBuffer(32,BHasEntry,INDICATOR_DATA);
 SetIndexBuffer(33,BEma50,INDICATOR_DATA); SetIndexBuffer(34,BEma200,INDICATOR_DATA);
 SetIndexBuffer(35,BVolumeStrength,INDICATOR_DATA); SetIndexBuffer(36,BUtc,INDICATOR_DATA); SetIndexBuffer(37,BSession,INDICATOR_DATA);
 string names[36]={"Fast EMA","Medium EMA","Slow EMA","Fusion Slow","Fusion Fast",
  "AX_TrendBull","AX_TrendBear","AX_LongEntry","AX_ShortEntry","AX_LongExit","AX_ShortExit",
  "AX_BuyConfidence","AX_SellConfidence","AX_FastWPR","AX_SlowWPR","AX_TurtleWPR","AX_Trend",
  "AX_RawFusion","AX_VWAP","AX_RSI","AX_RsiEMA","AX_MACD","AX_MACDSignal","AX_MACDHist",
  "AX_StochK","AX_StochD","AX_ATR","AX_BullScore","AX_BearScore","AX_Condition","AX_HasEntry",
  "AX_EMA50","AX_EMA200","AX_VolumeStrength","AX_UTC","AX_Session"};
 for(int p=0;p<36;p++)
 {
  PlotIndexSetString(p,PLOT_LABEL,names[p]); PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
  PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE); PlotIndexSetInteger(p,PLOT_SHOW_DATA,true);
 }
 // Fast EMA crosses are rendered as actual plus signs on the foreground canvas.
 PlotIndexSetInteger(1,PLOT_DRAW_TYPE,InpShowEmaMedium?DRAW_LINE:DRAW_NONE);
 PlotIndexSetInteger(1,PLOT_LINE_COLOR,InpEmaMediumColor); PlotIndexSetInteger(1,PLOT_LINE_WIDTH,1);
 PlotIndexSetInteger(2,PLOT_DRAW_TYPE,InpShowEmaSlow?DRAW_LINE:DRAW_NONE);
 PlotIndexSetInteger(2,PLOT_LINE_COLOR,InpEmaSlowColor); PlotIndexSetInteger(2,PLOT_LINE_WIDTH,2);
 for(int p=3;p<=4;p++)
 {
  PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_COLOR_LINE); PlotIndexSetInteger(p,PLOT_COLOR_INDEXES,3);
  PlotIndexSetInteger(p,PLOT_LINE_COLOR,0,InpNeutral); PlotIndexSetInteger(p,PLOT_LINE_COLOR,1,InpBullPrimary);
  PlotIndexSetInteger(p,PLOT_LINE_COLOR,2,InpBearPrimary); PlotIndexSetInteger(p,PLOT_LINE_WIDTH,p==3?2:1);
 }
 IndicatorSetString(INDICATOR_SHORTNAME,"AlphaX Vision"); IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
 Renderer.Init("AXV_"+(string)ChartID()+"_"+(string)GetMicrosecondCount()+"_");
 EventSetMillisecondTimer(250);
 Print("AlphaX Vision loaded. Match broker UTC offset, volume and VWAP anchor to the TradingView feed. Existing Pine divergence condition preserved.");
 return INIT_SUCCEEDED;
}
void PutBuffers(const int i,const AXBar &b)
{
 BFast[i]=InpShowEmaFast?b.emaFast:EMPTY_VALUE; BMedium[i]=InpShowEmaMedium?b.emaMedium:EMPTY_VALUE;
 BSlow[i]=InpShowEmaSlow?b.emaSlow:EMPTY_VALUE;
 BFusionSlow[i]=b.fusionSlow; BFusionFast[i]=b.fusionFast;
 BSlowColor[i]=BFastColor[i]=b.bullish?1:b.bearish?2:0;
 BTrendBull[i]=(double)b.trendBull; BTrendBear[i]=(double)b.trendBear;
 BLongEntry[i]=(double)b.longEntry; BShortEntry[i]=(double)b.shortEntry;
 BLongExit[i]=(double)b.longExit; BShortExit[i]=(double)b.shortExit;
 BBuyConfidence[i]=b.buyConfidence; BSellConfidence[i]=b.sellConfidence;
 BFastWpr[i]=b.fastWpr; BSlowWpr[i]=b.slowWpr; BTurtleWpr[i]=b.turtleWpr; BTrend[i]=b.currentTrend;
 BRawFusion[i]=b.rawFusion; BVwap[i]=b.vwap; BRsi[i]=b.rsi; BRsiEma[i]=b.rsiEma;
 BMacd[i]=b.macd; BMacdSignal[i]=b.macdSignal; BHist[i]=b.hist; BStochK[i]=b.stochK; BStochD[i]=b.stochD;
 BAtr[i]=b.atr; BBullScore[i]=b.bullFusionScore; BBearScore[i]=b.bearFusionScore;
 BCondition[i]=b.bullish?1:b.bearish?-1:0; BHasEntry[i]=(double)b.hasEntry;
 BEma50[i]=b.ema50; BEma200[i]=b.ema200; BVolumeStrength[i]=b.volumeStrength;
 BUtc[i]=(double)b.utc; BSession[i]=(double)b.sessionKey;
}
string Number(const double x) { return AXValid(x)?DoubleToString(x,15):""; }
void ExportCsv(const int count,const bool reset)
{
 if(!InpExportCsv||count<2) return;
 if(reset||csvHandle==INVALID_HANDLE)
 {
  if(csvHandle!=INVALID_HANDLE) FileClose(csvHandle);
  csvHandle=FileOpen(InpExportName,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',',CP_UTF8); csvWritten=0;
  if(csvHandle==INVALID_HANDLE) { Print("AlphaX: CSV open failed: ",GetLastError()); return; }
  FileWrite(csvHandle,"time","open","high","low","close","volume","AX_EMAFast","AX_EMAMedium","AX_EMASlow",
   "AX_FusionSlow","AX_FusionFast","AX_VWAP","AX_RawFusion","AX_RSI","AX_RsiEMA","AX_MACD","AX_MACDSignal","AX_MACDHist",
   "AX_StochK","AX_StochD","AX_FastWPR","AX_SlowWPR","AX_TurtleWPR","AX_BuyConfidence","AX_SellConfidence",
   "AX_TrendBull","AX_TrendBear","AX_LongEntry","AX_ShortEntry","AX_LongExit","AX_ShortExit","AX_Trend","AX_ATR",
   "AX_BullScore","AX_BearScore","AX_Condition","AX_HasEntry","AX_EMA50","AX_EMA200","AX_VolumeStrength");
 }
 for(int i=csvWritten;i<count-1;i++)
 {
  AXBar b=Engine.v[i]; if(InpCalculationStartUTC>0&&b.utc<InpCalculationStartUTC) continue;
  double vol=InpVolume==AX_TICK_VOLUME?(double)Rates[i].tick_volume:(double)Rates[i].real_volume;
  FileWrite(csvHandle,(long)b.utc,Number(Rates[i].open),Number(Rates[i].high),Number(Rates[i].low),Number(Rates[i].close),Number(vol),
   Number(b.emaFast),Number(b.emaMedium),Number(b.emaSlow),Number(b.fusionSlow),Number(b.fusionFast),Number(b.vwap),Number(b.rawFusion),
   Number(b.rsi),Number(b.rsiEma),Number(b.macd),Number(b.macdSignal),Number(b.hist),Number(b.stochK),Number(b.stochD),
   Number(b.fastWpr),Number(b.slowWpr),Number(b.turtleWpr),Number(b.buyConfidence),Number(b.sellConfidence),
   (int)b.trendBull,(int)b.trendBear,(int)b.longEntry,(int)b.shortEntry,(int)b.longExit,(int)b.shortExit,b.currentTrend,Number(b.atr),
   b.bullFusionScore,b.bearFusionScore,b.bullish?1:b.bearish?-1:0,(int)b.hasEntry,Number(b.ema50),Number(b.ema200),Number(b.volumeStrength));
 }
 csvWritten=count-1; FileFlush(csvHandle);
}
int SignalMask(const AXBar &b)
{
 return (b.trendBull&&InpAlertTrendBull?1:0)|(b.trendBear&&InpAlertTrendBear?2:0)|
  (b.longEntry&&InpAlertLongEntry?4:0)|(b.shortEntry&&InpAlertShortEntry?8:0)|
  (b.longExit&&InpAlertLongExit?16:0)|(b.shortExit&&InpAlertShortExit?32:0);
}
void Notify(const int mask)
{
 string action[6]={"BULL trend","BEAR trend","Re-entry LONG","Re-entry SHORT","EXIT long","EXIT short"};
 string tf=EnumToString(_Period); StringReplace(tf,"PERIOD_","");
 for(int k=0;k<6;k++) if((mask&(1<<k))!=0)
 {
  string message="AlphaX Vision: "+action[k]+" ("+_Symbol+" "+tf+")";
  if(InpPopupAlerts) Alert(message);
  if(InpPushAlerts&&!SendNotification(message)) Print("AlphaX push failed: ",GetLastError());
  if(InpEmailAlerts&&!SendMail("AlphaX Vision",message)) Print("AlphaX email failed: ",GetLastError());
 }
}
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
 const double &open[],const double &high[],const double &low[],const double &close[],
 const long &tick_volume[],const long &volume[],const int &spread[])
{
 if(rates_total<1) return 0;
 ArraySetAsSeries(time,false); ArraySetAsSeries(open,false); ArraySetAsSeries(high,false);
 ArraySetAsSeries(low,false); ArraySetAsSeries(close,false); ArraySetAsSeries(tick_volume,false);
 ArraySetAsSeries(volume,false); ArraySetAsSeries(spread,false);
 bool reset=prev_calculated<=0||prev_calculated>rates_total||firstTime!=time[0];
 int from=reset?0:MathMax(0,prev_calculated-1);
 if(reset) { calculationStart=-1; initialized=false; firstTime=time[0]; }
 ArrayResize(Rates,rates_total,2048); Engine.Resize(rates_total);
 for(int i=from;i<rates_total;i++)
 {
  Rates[i].time=time[i]; Rates[i].open=open[i]; Rates[i].high=high[i]; Rates[i].low=low[i]; Rates[i].close=close[i];
  Rates[i].tick_volume=tick_volume[i]; Rates[i].real_volume=volume[i]; Rates[i].spread=spread[i];
  if(calculationStart<0&&AXToUTC(time[i],Engine.c)>=InpCalculationStartUTC) calculationStart=i;
  if(calculationStart<0) { AXEmpty(Engine.v[i]); PutBuffers(i,Engine.v[i]); continue; }
  // Core.start prevents all lookbacks from leaking before the selected start.
 }
 if(calculationStart>=0)
 {
  Engine.start=calculationStart;
  for(int i=MathMax(from,calculationStart);i<rates_total;i++) { Engine.Step(Rates,i); PutBuffers(i,Engine.v[i]); }
 }
 if(calculationStart<0) { Renderer.Destroy(); return rates_total; }
 ExportCsv(rates_total,reset);
 int last=rates_total-1;
 if(!initialized)
 {
  initialized=true; lastAlertTime=time[last]; lastAlertMask=SignalMask(Engine.v[last]);
  lastClosedAlert=last>0?time[last-1]:0;
 }
 else if(InpAlertAtBarClose)
 {
  if(last>0&&time[last-1]>lastClosedAlert) { Notify(SignalMask(Engine.v[last-1])); lastClosedAlert=time[last-1]; }
 }
 else
 {
  if(lastAlertTime!=time[last]) { lastAlertTime=time[last]; lastAlertMask=0; }
  int mask=SignalMask(Engine.v[last]),fresh=mask&~lastAlertMask;
  if(fresh!=0) { Notify(fresh); lastAlertMask|=fresh; }
 }
 Renderer.Draw(Rates,Engine.v,Theme,InpAtrOffset);
 return rates_total;
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{ if(id==CHARTEVENT_CHART_CHANGE&&initialized) Renderer.Draw(Rates,Engine.v,Theme,InpAtrOffset,true); }
void OnTimer(void)
{ if(initialized&&Renderer.Pending()) Renderer.Draw(Rates,Engine.v,Theme,InpAtrOffset); }
void OnDeinit(const int reason)
{
 EventKillTimer(); Renderer.Destroy();
 if(csvHandle!=INVALID_HANDLE) { FileClose(csvHandle); csvHandle=INVALID_HANDLE; }
 ChartRedraw();
}
