#property copyright "AlphaX"
#property version "1.00"
#include "..\AlphaX_Vision_Core.mqh"
int checks=0,failures=0;
void Check(const bool ok,const string label)
{ checks++; if(!ok) { failures++; Print("FAIL: ",label); } }
bool Same(const double a,const double b)
{ return a==b||(!AXValid(a)&&!AXValid(b))||(AXValid(a)&&AXValid(b)&&MathAbs(a-b)<1e-10); }
bool SameBar(const AXBar &a,const AXBar &b)
{
 return Same(a.fusionSlow,b.fusionSlow)&&Same(a.fusionFast,b.fusionFast)&&Same(a.emaFast,b.emaFast)&&
 Same(a.rsi,b.rsi)&&Same(a.atr,b.atr)&&Same(a.vwap,b.vwap)&&Same(a.cumulativePV,b.cumulativePV)&&
 Same(a.buyConfidence,b.buyConfidence)&&Same(a.sellConfidence,b.sellConfidence)&&
 a.currentTrend==b.currentTrend&&a.hasEntry==b.hasEntry&&a.lastTrendLabel==b.lastTrendLabel&&
 a.trendBull==b.trendBull&&a.trendBear==b.trendBear&&a.longEntry==b.longEntry&&a.shortEntry==b.shortEntry&&
 a.longExit==b.longExit&&a.shortExit==b.shortExit&&Same(a.currLowPrice,b.currLowPrice)&&Same(a.currHighPrice,b.currHighPrice);
}
string N(const double x) { return AXValid(x)?DoubleToString(x,15):""; }
void Dump(const string name,const MqlRates &r[],const AXBar &v[])
{
 int f=FileOpen("AlphaX_"+name+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
 Check(f!=INVALID_HANDLE,"open "+name); if(f==INVALID_HANDLE) return;
 FileWrite(f,"server_time","time","open","high","low","close","tick_volume","real_volume","session",
 "AX_EMAFast","AX_EMAMedium","AX_EMASlow","AX_FusionEMA","AX_SMA","AX_WMA","AX_ALMA","AX_VWAP","AX_RawFusion",
 "AX_FusionSlow","AX_FusionFast","AX_RSI","AX_RsiEMA","AX_MACD","AX_MACDSignal","AX_MACDHist","AX_StochK","AX_StochD",
 "AX_FastWPR","AX_SlowWPR","AX_TurtleWPR","AX_BuyConfidence","AX_SellConfidence","AX_TrendBull","AX_TrendBear",
 "AX_LongEntry","AX_ShortEntry","AX_LongExit","AX_ShortExit","AX_Trend","AX_ATR","AX_BullScore","AX_BearScore",
 "AX_Condition","AX_HasEntry","AX_EMA50","AX_EMA200","AX_VolumeStrength","buy_triggers","sell_triggers");
 for(int i=0;i<ArraySize(r);i++)
 {
  AXBar b=v[i];
  FileWrite(f,(long)r[i].time,(long)b.utc,N(r[i].open),N(r[i].high),N(r[i].low),N(r[i].close),r[i].tick_volume,r[i].real_volume,b.sessionKey,
   N(b.emaFast),N(b.emaMedium),N(b.emaSlow),N(b.fusionEma),N(b.sma),N(b.wma),N(b.alma),N(b.vwap),N(b.rawFusion),N(b.fusionSlow),N(b.fusionFast),
   N(b.rsi),N(b.rsiEma),N(b.macd),N(b.macdSignal),N(b.hist),N(b.stochK),N(b.stochD),N(b.fastWpr),N(b.slowWpr),N(b.turtleWpr),
   N(b.buyConfidence),N(b.sellConfidence),(int)b.trendBull,(int)b.trendBear,(int)b.longEntry,(int)b.shortEntry,(int)b.longExit,(int)b.shortExit,
   b.currentTrend,N(b.atr),b.bullFusionScore,b.bearFusionScore,b.bullish?1:b.bearish?-1:0,(int)b.hasEntry,N(b.ema50),N(b.ema200),N(b.volumeStrength),
   b.buyTriggers,b.sellTriggers);
 }
 FileClose(f);
}
void OnStart(void)
{
 const int count=6000;
 MqlRates r[]; ArrayResize(r,count); uint rng=12345; double price=2900;
 for(int i=0;i<count;i++)
 {
  rng=1664525*rng+1013904223;
  double noise=((rng>>8)%10001)/10000.0-0.5;
  r[i].time=D'2026.03.27 00:00'+i*60;
  r[i].open=price;
  double drift=(i/300)%3==0?0.15:(i/300)%3==1?-0.15:0;
  price+=0.8*MathSin(i*0.21)+noise*4+drift;
  if(i%147==0) price+=(i%294==0?20:-20);
  r[i].close=price; r[i].high=MathMax(price,r[i].open)+0.1+MathAbs(noise);
  r[i].low=MathMin(price,r[i].open)-0.1-MathAbs(noise*1.7);
  if(i<40) { price=2900; r[i].open=price; r[i].close=price; r[i].high=price; r[i].low=price; }
  r[i].open=NormalizeDouble(r[i].open,5); r[i].high=NormalizeDouble(r[i].high,5);
  r[i].low=NormalizeDouble(r[i].low,5); r[i].close=NormalizeDouble(r[i].close,5);
  r[i].tick_volume=i<20||i%131==0?0:100+(rng%500);
  r[i].real_volume=i<20||i%29==0?0:50+(rng%300);
  r[i].spread=20;
 }
 AXConfig c; AXDefaults(c);
 CAlphaXEngine baseline; baseline.Configure(c); baseline.Resize(count);
 for(int i=0;i<count;i++)
 {
  baseline.Step(r,i); AXBar expected=baseline.v[i];
  if(i%37==0)
  {
   baseline.Step(r,i); Check(SameBar(expected,baseline.v[i]),"repeat current bar "+(string)i);
   MqlRates original=r[i]; r[i].close+=17; r[i].high=MathMax(r[i].high,r[i].close); r[i].tick_volume+=31;
   baseline.Step(r,i); r[i]=original; baseline.Step(r,i);
   Check(SameBar(expected,baseline.v[i]),"intrabar rollback "+(string)i);
  }
  Check(!baseline.v[i].bullDivergence&&!baseline.v[i].bearDivergence,"preserved divergence "+(string)i);
 }
 Dump("default",r,baseline.v);
 for(int scenario=1;scenario<=8;scenario++)
 {
  AXDefaults(c); string name;
  if(scenario==1) { c.strictGate=false; name="strict_off"; }
  if(scenario==2) { c.enableTrendGate=false; c.minConfidence=60; name="gate_off_conf60"; }
  if(scenario==3) { c.requireRecovery=false; name="recovery_off"; }
  if(scenario==4) { c.dateFilter=true; c.startDate=AXToUTC(r[2200].time,c); c.endDate=AXToUTC(r[4200].time,c); name="date_filter"; }
  if(scenario==5) { c.volumeSource=AX_REAL_VOLUME; name="real_volume"; }
  if(scenario==6) { c.brokerClock=AX_EU_DST; c.vwapAnchor=AX_NEW_YORK_1700; name="eu_ny_session"; }
  if(scenario==7) { c.vwapAnchor=AX_UTC_SESSION; c.sessionStartMinutes=480; name="utc_session_0800"; }
  if(scenario==8)
  {
   c.fusionLength=7; c.slowSensitivity=3; c.fastSensitivity=2;
   c.fastWprPeriod=3; c.slowWprPeriod=15; c.turtleWprPeriod=100;
   c.oversold=-70; c.overbought=-30; c.recoveryBars=10; c.recoveryMove=20; c.cooldown=1;
   c.emaFastLength=1; c.emaMediumLength=1; c.emaSlowLength=500; name="parameter_edges";
  }
  CAlphaXEngine variant; variant.Configure(c); variant.Resize(count);
  for(int i=0;i<count;i++)
  {
   variant.Step(r,i);
   if(scenario==4)
   {
    AXBar b=variant.v[i];
    Check(b.trendBull==baseline.v[i].trendBull&&b.trendBear==baseline.v[i].trendBear,"date filter preserves trend "+(string)i);
    if(i<2200||i>4200) Check(!b.longEntry&&!b.shortEntry&&!b.longExit&&!b.shortExit,"date filter boundaries "+(string)i);
   }
  }
  Dump(name,r,variant.v);
 }
 AXDefaults(c);
 CAlphaXEngine sliced,offset; sliced.Configure(c); offset.Configure(c);
 int start=137; MqlRates tail[]; ArrayResize(tail,count-start); ArrayCopy(tail,r,0,start);
 sliced.Resize(count-start); offset.Resize(count); offset.start=start;
 for(int i=start;i<count;i++)
 {
  sliced.Step(tail,i-start); offset.Step(r,i);
  AXBar a=sliced.v[i-start],b=offset.v[i];
  Check(Same(a.fusionSlow,b.fusionSlow)&&Same(a.rsi,b.rsi)&&Same(a.atr,b.atr)&&a.longEntry==b.longEntry&&a.trendBull==b.trendBull,
        "dataset start no leakage "+(string)i);
 }
 c.brokerClock=AX_EU_DST;
 Check(AXToUTC(D'2026.01.20 12:00',c)==D'2026.01.20 10:00',"winter UTC");
 Check(AXToUTC(D'2026.07.20 12:00',c)==D'2026.07.20 09:00',"summer UTC");
 Check(AXAmericanDST(D'2026.03.08 07:00')&&!AXAmericanDST(D'2026.03.08 06:59'),"US DST start");
 Check(AXEuropeanDST(D'2026.03.29 01:00')&&!AXEuropeanDST(D'2026.03.29 00:59'),"EU DST start");

 // Exercise the actual compiled indicator, all buffers and bitmap rendering.
 string symbol="AXVISION_TEST";
 bool exists=false; if(!SymbolExist(symbol,exists)) Check(CustomSymbolCreate(symbol,"AlphaXValidation"),"create custom symbol");
 CustomSymbolSetInteger(symbol,SYMBOL_DIGITS,5); CustomSymbolSetDouble(symbol,SYMBOL_POINT,0.00001);
 CustomSymbolSetDouble(symbol,SYMBOL_TRADE_TICK_SIZE,0.00001);
 Check(CustomRatesReplace(symbol,0,D'2030.01.01',r)==count,"custom history load");
 SymbolSelect(symbol,true);
 long chart=ChartOpen(symbol,PERIOD_M1);
 Check(chart>0,"open offline chart");
 if(chart>0)
 {
  ChartSetInteger(chart,CHART_MODE,CHART_CANDLES); ChartSetInteger(chart,CHART_SHOW_GRID,false);
  ChartSetInteger(chart,CHART_COLOR_BACKGROUND,C'17,20,27'); ChartSetInteger(chart,CHART_COLOR_FOREGROUND,C'180,185,195');
  ChartSetInteger(chart,CHART_COLOR_CANDLE_BULL,C'42,178,145'); ChartSetInteger(chart,CHART_COLOR_CANDLE_BEAR,C'220,80,100');
  ChartSetInteger(chart,CHART_COLOR_CHART_UP,C'42,178,145'); ChartSetInteger(chart,CHART_COLOR_CHART_DOWN,C'220,80,100');
  ChartSetInteger(chart,CHART_SCALE,3); ChartSetInteger(chart,CHART_SHIFT,true);
  int handle=iCustom(symbol,PERIOD_M1,"AlphaX_Vision");
  Check(handle!=INVALID_HANDLE,"load compiled indicator");
  if(handle!=INVALID_HANDLE)
  {
   Check(ChartIndicatorAdd(chart,0,handle),"attach indicator");
   for(int attempt=0;attempt<80&&BarsCalculated(handle)<count;attempt++) Sleep(100);
   Check(BarsCalculated(handle)==count,"indicator calculated all fixture bars");
   int tested[12]={0,3,5,7,8,9,10,11,12,13,14,28};
   for(int k=0;k<12;k++)
   {
    double buffer[]; int copied=CopyBuffer(handle,tested[k],0,count,buffer);
    Check(copied==count,"copy indicator buffer "+(string)tested[k]); if(copied!=count) continue;
    for(int i=0;i<count;i++)
    {
     AXBar b=baseline.v[i]; double expected=0;
     switch(tested[k])
     {
      case 0: expected=b.emaFast; break; case 3: expected=b.fusionSlow; break; case 5: expected=b.fusionFast; break;
      case 7: expected=(double)b.trendBull; break; case 8: expected=(double)b.trendBear; break;
      case 9: expected=(double)b.longEntry; break; case 10: expected=(double)b.shortEntry; break;
      case 11: expected=(double)b.longExit; break; case 12: expected=(double)b.shortExit; break;
      case 13: expected=b.buyConfidence; break; case 14: expected=b.sellConfidence; break; case 28: expected=b.atr; break;
     }
     Check(Same(buffer[i],expected),"indicator/core "+(string)tested[k]+" bar "+(string)i);
    }
   }
   ChartNavigate(chart,CHART_END,0); ChartRedraw(chart); Sleep(1500);
   Check(ChartScreenShot(chart,"AlphaX_Vision_preview.png",1440,900,ALIGN_RIGHT),"chart screenshot");
   // Leave time for queued chart changes and canvas redraws before shutdown.
   Sleep(500); IndicatorRelease(handle);
  }
 }
 int report=FileOpen("AlphaX_selftest.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
 if(report!=INVALID_HANDLE) { FileWrite(report,"checks="+(string)checks+" failures="+(string)failures); FileClose(report); }
 Print("AlphaX validation finished: ",checks," checks; ",failures," failures.");
}
