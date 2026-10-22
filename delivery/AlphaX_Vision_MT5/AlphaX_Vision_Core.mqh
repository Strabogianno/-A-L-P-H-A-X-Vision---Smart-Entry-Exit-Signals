// Original indicator logic: (c) AlphaX. Native MQL5 port, October 2026.
// Calculations are independent of terminal indicators and chart rendering.
#ifndef ALPHAX_VISION_CORE_MQH
#define ALPHAX_VISION_CORE_MQH

enum AX_VOLUME { AX_TICK_VOLUME=0, AX_REAL_VOLUME=1 };
enum AX_CLOCK { AX_FIXED_OFFSET=0, AX_EU_DST=1, AX_US_DST=2 };
enum AX_ANCHOR { AX_BROKER_MIDNIGHT=0, AX_UTC_SESSION=1, AX_NEW_YORK_1700=2 };
enum AX_LABEL_SIZE { AX_SIZE_TINY=0, AX_SIZE_SMALL=1, AX_SIZE_NORMAL=2 };

struct AXConfig
{
 int fusionLength, slowSensitivity, fastSensitivity;
 int emaFastLength, emaMediumLength, emaSlowLength;
 int fastWprPeriod, slowWprPeriod, turtleWprPeriod;
 int oversold, overbought, trendLookback;
 double minConfidence;
 bool enableTrendGate, strictGate;
 double upTurtle, upSlow, downTurtle, downSlow;
 bool requireRecovery;
 int recoveryBars;
 double recoveryMove;
 int cooldown;
 double atrOffset;
 bool dateFilter;
 datetime startDate, endDate;
 AX_VOLUME volumeSource;
 AX_CLOCK brokerClock;
 int winterOffsetMinutes;
 AX_ANCHOR vwapAnchor;
 int sessionStartMinutes;
};

void AXDefaults(AXConfig &c)
{
 c.fusionLength=122; c.slowSensitivity=12; c.fastSensitivity=5;
 c.emaFastLength=21; c.emaMediumLength=55; c.emaSlowLength=120;
 c.fastWprPeriod=21; c.slowWprPeriod=55; c.turtleWprPeriod=120;
 c.oversold=-90; c.overbought=-10; c.trendLookback=20; c.minConfidence=14;
 c.enableTrendGate=true; c.strictGate=true;
 c.upTurtle=-35; c.upSlow=-40; c.downTurtle=-65; c.downSlow=-60;
 c.requireRecovery=true; c.recoveryBars=3; c.recoveryMove=6;
 c.cooldown=25; c.atrOffset=2.4;
 c.dateFilter=false; c.startDate=D'2026.03.20 00:00'; c.endDate=D'2026.03.21 23:59';
 c.volumeSource=AX_TICK_VOLUME; c.brokerClock=AX_FIXED_OFFSET;
 c.winterOffsetMinutes=120; c.vwapAnchor=AX_BROKER_MIDNIGHT; c.sessionStartMinutes=0;
}

bool AXValid(const double x) { return x!=EMPTY_VALUE && MathIsValidNumber(x); }
bool AXGT(const double a,const double b) { return AXValid(a)&&AXValid(b)&&a>b; }
bool AXLT(const double a,const double b) { return AXValid(a)&&AXValid(b)&&a<b; }
bool AXGE(const double a,const double b) { return AXValid(a)&&AXValid(b)&&a>=b; }
bool AXLE(const double a,const double b) { return AXValid(a)&&AXValid(b)&&a<=b; }
double AXEMA(const double x,const double previous,const int length)
{
 if(!AXValid(x)) return previous; // Pine ignores na observations.
 if(!AXValid(previous)) return x;
 double alpha=2.0/(length+1.0);
 return alpha*x+(1.0-alpha)*previous;
}

datetime AXDate(const int year,const int month,const int day,const int hour=0)
{
 MqlDateTime d={}; d.year=year; d.mon=month; d.day=day; d.hour=hour;
 return StructToTime(d);
}
int AXSunday(const int year,const int month,const int occurrence)
{
 MqlDateTime d; TimeToStruct(AXDate(year,month,1),d);
 return 1+(7-d.day_of_week)%7+7*(occurrence-1);
}
bool AXEuropeanDST(const datetime utc)
{
 MqlDateTime d,t; TimeToStruct(utc,d);
 TimeToStruct(AXDate(d.year,3,31),t); int march=31-t.day_of_week;
 TimeToStruct(AXDate(d.year,10,31),t); int october=31-t.day_of_week;
 return utc>=AXDate(d.year,3,march,1) && utc<AXDate(d.year,10,october,1);
}
bool AXAmericanDST(const datetime utc)
{
 MqlDateTime d; TimeToStruct(utc,d);
 // Current US rules, valid from 2007. Use fixed offsets for older history.
 return utc>=AXDate(d.year,3,AXSunday(d.year,3,2),7) &&
        utc<AXDate(d.year,11,AXSunday(d.year,11,1),6);
}
datetime AXToUTC(const datetime server,const AXConfig &c)
{
 datetime candidate=server-c.winterOffsetMinutes*60;
 bool dst=c.brokerClock==AX_EU_DST ? AXEuropeanDST(candidate) :
          c.brokerClock==AX_US_DST ? AXAmericanDST(candidate) : false;
 return candidate-(dst?3600:0);
}
long AXSessionKey(const datetime server,const datetime utc,const AXConfig &c)
{
 if(c.vwapAnchor==AX_BROKER_MIDNIGHT) return (long)server/86400;
 if(c.vwapAnchor==AX_UTC_SESSION) return ((long)utc-c.sessionStartMinutes*60)/86400;
 // A daily trading session beginning at 17:00 New York local time.
 long local=(long)utc+(AXAmericanDST(utc)?-4:-5)*3600;
 return (local-17*3600)/86400;
}

struct AXBar
{
 double emaFast,emaMedium,emaSlow,fusionEma,sma,wma,alma,vwap,rawFusion,fusionSlow,fusionFast;
 double ema50,ema200,ema12,ema26,macd,macdSignal,hist;
 double avgGain,avgLoss,gainSeed,lossSeed,rsi,rsiEma,stochK,stochD;
 int rsiSamples;
 double tr,trSeed,atr,fastWpr,slowWpr,turtleWpr,volumeStrength;
 double cumulativePV,cumulativeVolume;
 long sessionKey;
 datetime utc;
 bool bullish,bearish,neutral,trendBull,trendBear,longEntry,shortEntry,longExit,shortExit;
 int lastTrendLabel,lastDirection,currentTrend;
 bool hasEntry;
 double prevLowPrice,prevLowWpr,currLowPrice,currLowWpr;
 double prevHighPrice,prevHighWpr,currHighPrice,currHighWpr;
 int prevLowBar,currLowBar,prevHighBar,currHighBar;
 bool bullDivergence,bearDivergence,gatedBuy,gatedSell;
 int buyTriggers,sellTriggers,bullFusionScore,bearFusionScore;
 double buyConfidence,sellConfidence;
};

void AXEmpty(AXBar &b)
{
 ZeroMemory(b);
 b.emaFast=b.emaMedium=b.emaSlow=b.fusionEma=b.sma=b.wma=b.alma=EMPTY_VALUE;
 b.vwap=b.rawFusion=b.fusionSlow=b.fusionFast=EMPTY_VALUE;
 b.ema50=b.ema200=b.ema12=b.ema26=b.macd=b.macdSignal=b.hist=EMPTY_VALUE;
 b.avgGain=b.avgLoss=b.rsi=b.rsiEma=b.stochK=b.stochD=b.atr=EMPTY_VALUE;
 b.fastWpr=b.slowWpr=b.turtleWpr=b.volumeStrength=EMPTY_VALUE;
 b.prevLowPrice=b.prevLowWpr=b.currLowPrice=b.currLowWpr=EMPTY_VALUE;
 b.prevHighPrice=b.prevHighWpr=b.currHighPrice=b.currHighWpr=EMPTY_VALUE;
 b.prevLowBar=b.currLowBar=b.prevHighBar=b.currHighBar=-1;
 b.neutral=true;
}

class CAlphaXEngine
{
private:
 double weights[];
 double weightSum;
 double RangeOscillator(const MqlRates &r[],const int i,const int length,const bool wpr)
 {
  double highest=r[i].high,lowest=r[i].low;
  for(int j=MathMax(start,i-length+1);j<i;j++)
  { highest=MathMax(highest,r[j].high); lowest=MathMin(lowest,r[j].low); }
  if(highest==lowest) return EMPTY_VALUE;
  return wpr ? -100.0*(highest-r[i].close)/(highest-lowest) :
                100.0*(r[i].close-lowest)/(highest-lowest);
 }
 double Volume(const MqlRates &r) { return c.volumeSource==AX_TICK_VOLUME ? (double)r.tick_volume : (double)r.real_volume; }

public:
 int start;
 AXConfig c;
 AXBar v[];
 void Configure(const AXConfig &config)
 {
  c=config; start=0; ArrayResize(v,0); ArrayResize(weights,c.fusionLength); weightSum=0;
  double m=0.85*(c.fusionLength-1),s=c.fusionLength/6.0;
  for(int k=0;k<c.fusionLength;k++)
  { weights[k]=MathExp(-MathPow(k-m,2)/(2*s*s)); weightSum+=weights[k]; }
 }
 void Resize(const int n) { ArrayResize(v,n,2048); }
 void Step(const MqlRates &r[],const int i)
 {
  AXBar p,b; AXEmpty(p); if(i>start) p=v[i-1]; b=p;
  double close=r[i].close,high=r[i].high,low=r[i].low,open=r[i].open;
  b.utc=AXToUTC(r[i].time,c); b.sessionKey=AXSessionKey(r[i].time,b.utc,c);
  b.emaFast=AXEMA(close,p.emaFast,c.emaFastLength);
  b.emaMedium=AXEMA(close,p.emaMedium,c.emaMediumLength);
  b.emaSlow=AXEMA(close,p.emaSlow,c.emaSlowLength);
  b.fusionEma=AXEMA(close,p.fusionEma,c.fusionLength);
  b.sma=b.wma=b.alma=EMPTY_VALUE;
  if(i-start>=c.fusionLength-1)
  {
   double sum=0,weighted=0,almaSum=0;
   for(int k=0;k<c.fusionLength;k++)
   {
    double price=r[i-c.fusionLength+1+k].close;
    sum+=price; weighted+=price*(k+1); almaSum+=price*weights[k];
   }
   b.sma=sum/c.fusionLength;
   b.wma=weighted/(c.fusionLength*(c.fusionLength+1)/2.0);
   b.alma=almaSum/weightSum;
  }
  bool reset=i==start || b.sessionKey!=p.sessionKey;
  double vol=Volume(r[i]);
  b.cumulativePV=(reset?0:p.cumulativePV)+(high+low+close)/3.0*vol;
  b.cumulativeVolume=(reset?0:p.cumulativeVolume)+vol;
  b.vwap=b.cumulativeVolume>0 ? b.cumulativePV/b.cumulativeVolume : EMPTY_VALUE;
  b.rawFusion=AXValid(b.sma)&&AXValid(b.vwap) ?
      (b.fusionEma+b.sma+b.wma+b.alma+b.vwap)/5.0 : EMPTY_VALUE;
  b.fusionSlow=AXEMA(b.rawFusion,p.fusionSlow,c.slowSensitivity);
  b.fusionFast=AXEMA(b.rawFusion,p.fusionFast,c.fastSensitivity);
  bool slopeUp=AXGT(b.fusionSlow,p.fusionSlow),slopeDown=AXLT(b.fusionSlow,p.fusionSlow);
  bool fastUp=AXGT(b.fusionFast,p.fusionFast),fastDown=AXLT(b.fusionFast,p.fusionFast);
  b.bullish=AXGT(close,b.fusionSlow)&&slopeUp;
  b.bearish=AXLT(close,b.fusionSlow)&&slopeDown;
  b.neutral=!b.bullish&&!b.bearish;
  bool alignedBull=AXGT(b.fusionFast,b.fusionSlow),alignedBear=AXLT(b.fusionFast,b.fusionSlow);

  b.ema50=AXEMA(close,p.ema50,50); b.ema200=AXEMA(close,p.ema200,200);
  b.ema12=AXEMA(close,p.ema12,12); b.ema26=AXEMA(close,p.ema26,26);
  b.macd=b.ema12-b.ema26; b.macdSignal=AXEMA(b.macd,p.macdSignal,9); b.hist=b.macd-b.macdSignal;
  if(i>start)
  {
   double change=close-r[i-1].close,gain=MathMax(change,0),loss=MathMax(-change,0);
   if(p.rsiSamples<14)
   {
    b.rsiSamples=p.rsiSamples+1; b.gainSeed=p.gainSeed+gain; b.lossSeed=p.lossSeed+loss;
    if(b.rsiSamples==14) { b.avgGain=b.gainSeed/14.0; b.avgLoss=b.lossSeed/14.0; }
   }
   else { b.avgGain=(gain+13.0*p.avgGain)/14.0; b.avgLoss=(loss+13.0*p.avgLoss)/14.0; }
  }
  b.rsi=EMPTY_VALUE;
  if(AXValid(b.avgGain)&&AXValid(b.avgLoss))
   b.rsi=b.avgLoss==0 ? (b.avgGain==0?EMPTY_VALUE:100.0) : 100.0-100.0/(1.0+b.avgGain/b.avgLoss);
  b.rsiEma=AXEMA(b.rsi,p.rsiEma,7);
  b.stochK=RangeOscillator(r,i,14,false);
  double stochSum=0; int stochCount=0;
  // ta.sma skips na values, including zero-range stochastic observations.
  if(AXValid(b.stochK)) { stochSum=b.stochK; stochCount=1; }
  for(int j=i-1;j>=start&&stochCount<3;j--)
   if(AXValid(v[j].stochK)) { stochSum+=v[j].stochK; stochCount++; }
  b.stochD=stochCount==3 ? stochSum/3.0 : EMPTY_VALUE;
  bool rsiUp=i-start>=2&&AXGT(b.rsiEma,p.rsiEma)&&AXGT(b.rsiEma,v[i-2].rsiEma);
  bool rsiDown=i-start>=2&&AXLT(b.rsiEma,p.rsiEma)&&AXLT(b.rsiEma,v[i-2].rsiEma);
  bool higherHigh=i-start>=2&&high>r[i-1].high&&r[i-1].high>r[i-2].high;
  bool lowerLow=i-start>=2&&low<r[i-1].low&&r[i-1].low<r[i-2].low;
  bool higherLow=i>start&&low>r[i-1].low,lowerHigh=i>start&&high<r[i-1].high;
  b.bullFusionScore=(AXGT(close,b.fusionSlow)&&AXGT(close,b.fusionFast))+(int)alignedBull+
   (slopeUp&&fastUp)+(close>b.emaMedium&&b.emaMedium>p.emaMedium)+
   (close>b.emaSlow||b.emaMedium>b.emaSlow)+(b.macd>b.macdSignal&&AXGT(b.hist,p.hist))+
   (AXGT(b.rsiEma,45)&&AXLT(b.rsiEma,75)&&rsiUp)+
   (AXGT(b.stochK,b.stochD)&&AXGT(b.stochK,30))+
   (close>(high+low)/2.0&&close>open&&(higherLow||higherHigh));
  b.bearFusionScore=(AXLT(close,b.fusionSlow)&&AXLT(close,b.fusionFast))+(int)alignedBear+
   (slopeDown&&fastDown)+(close<b.emaMedium&&AXLT(b.emaMedium,p.emaMedium))+
   (close<b.emaSlow||b.emaMedium<b.emaSlow)+(b.macd<b.macdSignal&&AXLT(b.hist,p.hist))+
   (AXLT(b.rsiEma,55)&&AXGT(b.rsiEma,25)&&rsiDown)+
   (AXLT(b.stochK,b.stochD)&&AXLT(b.stochK,70))+
   (close<(high+low)/2.0&&close<open&&(lowerHigh||lowerLow));

  b.trendBull=b.bullish&&i>start&&(p.bearish||p.neutral)&&
       (p.lastDirection!=1||i-p.lastTrendLabel>=c.cooldown);
  b.trendBear=b.bearish&&i>start&&(p.bullish||p.neutral)&&
       (p.lastDirection!=-1||i-p.lastTrendLabel>=c.cooldown);
  if(b.trendBull) { b.lastTrendLabel=i; b.lastDirection=1; }
  if(b.trendBear) { b.lastTrendLabel=i; b.lastDirection=-1; }

  b.fastWpr=RangeOscillator(r,i,c.fastWprPeriod,true);
  b.slowWpr=RangeOscillator(r,i,c.slowWprPeriod,true);
  b.turtleWpr=RangeOscillator(r,i,c.turtleWprPeriod,true);
  b.volumeStrength=EMPTY_VALUE;
  if(i-start>=19)
  {
   double sum=0; for(int j=i-19;j<=i;j++) sum+=Volume(r[j]);
   if(sum>0) b.volumeStrength=vol/(sum/20.0);
  }
  MqlDateTime tm; TimeToStruct(b.utc,tm); int hour=tm.hour;
  bool asia=hour<8,london=hour>=8&&hour<13,overlap=hour>=13&&hour<17;
  bool afternoon=hour>=17&&hour<21,nyClose=hour>=21;
  double sessionQuality=overlap?100:london?85:afternoon?60:asia?30:40;
  double velocityBase=overlap?1.0:london?0.9:afternoon?0.8:asia?0.5:0.6;
  double weak=3*velocityBase,idealMin=5*velocityBase,idealMax=30*velocityBase;
  double strong=35*velocityBase,extreme=45*velocityBase;
  double velocity=AXValid(b.fastWpr)&&AXValid(p.fastWpr)?b.fastWpr-p.fastWpr:EMPTY_VALUE;
  double absVel=AXValid(velocity)?MathAbs(velocity):EMPTY_VALUE;
  int quality=AXGE(absVel,idealMin)&&AXLE(absVel,idealMax)?0:
              AXGT(absVel,idealMax)&&AXLE(absVel,strong)?1:AXGT(absVel,strong)?2:3;
  bool crossUp=AXGT(b.fastWpr,c.oversold)&&AXLE(p.fastWpr,c.oversold);
  bool crossDown=AXLT(b.fastWpr,c.overbought)&&AXGE(p.fastWpr,c.overbought);
  bool slowUp=false,slowDown=false,turtleUp=false,turtleDown=false;
  if(i-start>=c.trendLookback)
  {
   AXBar older=v[i-c.trendLookback];
   if(AXValid(b.slowWpr)&&AXValid(older.slowWpr))
   { double slope=(b.slowWpr-older.slowWpr)/c.trendLookback; slowUp=slope>0.3; slowDown=slope< -0.3; }
   if(AXValid(b.turtleWpr)&&AXValid(older.turtleWpr))
   { double slope=(b.turtleWpr-older.turtleWpr)/c.trendLookback; turtleUp=slope>0.15; turtleDown=slope< -0.15; }
  }
  // Pine pivots are confirmed five bars after the pivot candle.
  if(i-start>=10)
  {
   int pivot=i-5; bool pivotLow=true,pivotHigh=true;
   for(int j=i-10;j<=i;j++)
   {
    if(j==pivot) continue;
    if(r[j].low<r[pivot].low||(j>pivot&&r[j].low==r[pivot].low)) pivotLow=false;
    if(r[j].high>r[pivot].high||(j>pivot&&r[j].high==r[pivot].high)) pivotHigh=false;
   }
   if(pivotLow)
   {
    b.prevLowPrice=b.currLowPrice; b.prevLowWpr=b.currLowWpr; b.prevLowBar=b.currLowBar;
    b.currLowPrice=r[pivot].low; b.currLowWpr=v[pivot].fastWpr; b.currLowBar=pivot;
   }
   if(pivotHigh)
   {
    b.prevHighPrice=b.currHighPrice; b.prevHighWpr=b.currHighWpr; b.prevHighBar=b.currHighBar;
    b.currHighPrice=r[pivot].high; b.currHighWpr=v[pivot].fastWpr; b.currHighBar=pivot;
   }
  }
  // Preserve the original <=3 test. Since confirmation requires 5 bars,
  // divergence is unreachable in the supplied Pine source. Do not silently fix it.
  b.bullDivergence=AXLT(b.currLowPrice,b.prevLowPrice)&&AXGT(b.currLowWpr,b.prevLowWpr)&&
    i-b.currLowBar<=3&&b.currLowBar-b.prevLowBar<=50&&b.currLowBar-b.prevLowBar>=5;
  b.bearDivergence=AXGT(b.currHighPrice,b.prevHighPrice)&&AXLT(b.currHighWpr,b.prevHighWpr)&&
    i-b.currHighBar<=3&&b.currHighBar-b.prevHighBar<=50&&b.currHighBar-b.prevHighBar>=5;
  bool divBuy=b.bullDivergence&&AXGT(velocity,weak),divSell=b.bearDivergence&&AXLT(velocity,-weak);
  bool snapBuy=AXLT(p.fastWpr,-88)&&AXGT(velocity,weak)&&
       (AXGT(b.turtleWpr,-65)||AXGT(b.slowWpr,-65))&&crossUp;
  bool snapSell=AXGT(p.fastWpr,-12)&&AXLT(velocity,-weak)&&
       (AXLT(b.turtleWpr,-35)||AXLT(b.slowWpr,-35))&&crossDown;
  bool exhaustBuy=AXLT(p.fastWpr,-78)&&(AXGT(b.turtleWpr,-75)||AXGT(b.slowWpr,-70))&&AXGT(velocity,weak)&&crossUp;
  bool exhaustSell=AXGT(p.fastWpr,-22)&&(AXLT(b.turtleWpr,-25)||AXLT(b.slowWpr,-30))&&AXLT(velocity,-weak)&&crossDown;
  bool continueBuy=crossUp&&((AXGT(b.turtleWpr,-30)&&AXGT(b.slowWpr,-40))||
      (AXGT(b.turtleWpr,-40)&&AXGT(b.slowWpr,-50)))&&(slowUp||turtleUp);
  bool continueSell=crossDown&&((AXLT(b.turtleWpr,-70)&&AXLT(b.slowWpr,-60))||
      (AXLT(b.turtleWpr,-60)&&AXLT(b.slowWpr,-50)))&&(slowDown||turtleDown);
  bool pullbackBuy=crossUp&&((AXGT(b.turtleWpr,-55)&&AXGT(b.slowWpr,-60))||AXGT(b.slowWpr,-60))&&AXGT(velocity,weak);
  bool pullbackSell=crossDown&&((AXLT(b.turtleWpr,-45)&&AXLT(b.slowWpr,-40))||AXLT(b.slowWpr,-40))&&AXLT(velocity,-weak);
  bool tripleBuy=AXLT(b.fastWpr,-78)&&AXLT(b.slowWpr,-68)&&AXLT(b.turtleWpr,-60)&&AXGT(velocity,weak)&&crossUp;
  bool tripleSell=AXGT(b.fastWpr,-22)&&AXGT(b.slowWpr,-32)&&AXGT(b.turtleWpr,-40)&&AXLT(velocity,-weak)&&crossDown;
  b.buyTriggers=(int)divBuy+(int)snapBuy+(int)exhaustBuy+(int)continueBuy+(int)pullbackBuy+(int)tripleBuy;
  b.sellTriggers=(int)divSell+(int)snapSell+(int)exhaustSell+(int)continueSell+(int)pullbackSell+(int)tripleSell;
  double buy=AXGT(b.turtleWpr,-35)?25:AXGT(b.turtleWpr,-45)?20:AXGT(b.turtleWpr,-55)?12:AXGT(b.turtleWpr,-65)?5:0;
  buy+=AXLT(b.fastWpr,-94)?20:AXLT(b.fastWpr,-90)?16:AXLT(b.fastWpr,-85)?12:AXLT(b.fastWpr,-80)?6:0;
  buy+=tripleBuy?20:continueBuy?18:divBuy?17:snapBuy?14:exhaustBuy?11:pullbackBuy?8:0;
  double sell=AXLT(b.turtleWpr,-65)?25:AXLT(b.turtleWpr,-55)?20:AXLT(b.turtleWpr,-45)?12:AXLT(b.turtleWpr,-35)?5:0;
  sell+=AXGT(b.fastWpr,-6)?20:AXGT(b.fastWpr,-10)?16:AXGT(b.fastWpr,-15)?12:AXGT(b.fastWpr,-20)?6:0;
  sell+=tripleSell?20:continueSell?18:divSell?17:snapSell?14:exhaustSell?11:pullbackSell?8:0;
  double common=(quality==0?15:quality==1?10:quality==2?3:6)+sessionQuality/10.0;
  common-=AXGT(absVel,extreme)?10:AXGT(absVel,strong)?5:0;
  common-=asia?10:nyClose?5:0; common-=AXLT(b.volumeStrength,0.7)?5:0;
  bool priceAbove=close>b.ema200,priceBelow=close<b.ema200;
  buy+=common+(priceAbove&&b.ema50>b.ema200?5:priceAbove?2:0)+(b.buyTriggers>=3?15:b.buyTriggers>=2?8:0);
  sell+=common+(priceBelow&&b.ema50<b.ema200?5:priceBelow?2:0)+(b.sellTriggers>=3?15:b.sellTriggers>=2?8:0);
  buy-=AXGT(b.rsi,72)?8:AXGT(b.rsi,65)?3:0;
  sell-=AXLT(b.rsi,28)?8:AXLT(b.rsi,35)?3:0;
  b.buyConfidence=MathMax(0,MathMin(100,buy)); b.sellConfidence=MathMax(0,MathMin(100,sell));
  bool buyPass=true,sellPass=true;
  double lowest=b.fastWpr,highest=b.fastWpr;
  for(int j=MathMax(start,i-c.recoveryBars);j<i;j++)
  {
   if(AXValid(v[j].fastWpr))
   { if(!AXValid(lowest)||v[j].fastWpr<lowest) lowest=v[j].fastWpr;
     if(!AXValid(highest)||v[j].fastWpr>highest) highest=v[j].fastWpr; }
  }
  if(c.enableTrendGate)
  {
   double adjustment=c.strictGate?5.0:0.0;
   if(AXLT(b.turtleWpr,c.downTurtle-adjustment)&&AXLT(b.slowWpr,c.downSlow-adjustment))
    buyPass=c.requireRecovery&&AXValid(lowest)&&AXGT(b.fastWpr,lowest+c.recoveryMove)&&AXLT(lowest,-80);
   if(AXGT(b.turtleWpr,c.upTurtle+adjustment)&&AXGT(b.slowWpr,c.upSlow+adjustment))
    sellPass=c.requireRecovery&&AXValid(highest)&&AXLT(b.fastWpr,highest-c.recoveryMove)&&AXGT(highest,-20);
  }
  b.gatedBuy=b.buyTriggers>0&&b.buyConfidence>=c.minConfidence&&buyPass;
  b.gatedSell=b.sellTriggers>0&&b.sellConfidence>=c.minConfidence&&sellPass;
  if(b.trendBull) { b.currentTrend=1; b.hasEntry=false; }
  if(b.trendBear) { b.currentTrend=-1; b.hasEntry=false; }
  bool inDate=!c.dateFilter||(b.utc>=c.startDate&&b.utc<=c.endDate);
  b.longEntry=b.currentTrend==1&&b.gatedBuy&&inDate;
  b.shortEntry=b.currentTrend==-1&&b.gatedSell&&inDate;
  b.longExit=b.currentTrend==1&&b.gatedSell&&b.hasEntry&&inDate;
  b.shortExit=b.currentTrend==-1&&b.gatedBuy&&b.hasEntry&&inDate;
  if(b.longEntry||b.shortEntry) b.hasEntry=true;
  b.tr=high-low;
  if(i>start) b.tr=MathMax(b.tr,MathMax(MathAbs(high-r[i-1].close),MathAbs(low-r[i-1].close)));
  b.trSeed=p.trSeed+b.tr;
  if(i-start==13) b.atr=b.trSeed/14.0;
  else if(i-start>13) b.atr=(b.tr+13.0*p.atr)/14.0;
  v[i]=b;
 }
};
#endif
