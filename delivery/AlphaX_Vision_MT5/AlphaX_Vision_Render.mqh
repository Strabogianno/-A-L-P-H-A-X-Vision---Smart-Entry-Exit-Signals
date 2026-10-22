#ifndef ALPHAX_VISION_RENDER_MQH
#define ALPHAX_VISION_RENDER_MQH
#include <Canvas\Canvas.mqh>
#include "AlphaX_Vision_Core.mqh"

struct AXTheme
{
 color bull,bullBright,bullDim,bear,bearBright,bearDim,neutral,emaFast;
 bool cloud,fastEma;
 AX_LABEL_SIZE size;
};

class CAXCanvas : public CCanvas
{
public:
 // Composite each cloud band, so overlapping layers retain their opacity.
 void BlendVertical(const int x,int top,int bottom,const color clr,const int opacity)
 {
  if(x<0||x>=m_width) return;
  top=MathMax(0,top); bottom=MathMin(m_height-1,bottom);
  uint src=ColorToARGB(clr,(uchar)opacity);
  double sa=opacity/255.0;
  for(int y=top;y<=bottom;y++)
  {
   int at=y*m_width+x; uint dst=m_pixels[at];
   double da=(dst>>24)/255.0,oa=sa+da*(1-sa);
   if(oa<=0) continue;
   int red=(int)MathRound((((src>>16)&255)*sa+((dst>>16)&255)*da*(1-sa))/oa);
   int green=(int)MathRound((((src>>8)&255)*sa+((dst>>8)&255)*da*(1-sa))/oa);
   int blue=(int)MathRound(((src&255)*sa+(dst&255)*da*(1-sa))/oa);
   m_pixels[at]=((uint)MathRound(oa*255)<<24)|((uint)red<<16)|((uint)green<<8)|(uint)blue;
  }
 }
};

class CAlphaXRenderer
{
private:
 CAXCanvas cloud,marks;
 string prefix;
 bool ready,warned,pending;
 int width,height;
 ulong lastRender;
 bool Create(const int w,const int h)
 {
  Destroy();
  if(!cloud.CreateBitmapLabel(0,0,prefix+"Cloud",0,0,w,h,COLOR_FORMAT_ARGB_NORMALIZE)||
     !marks.CreateBitmapLabel(0,0,prefix+"Marks",0,0,w,h,COLOR_FORMAT_ARGB_NORMALIZE))
  {
   if(!warned) { Print("AlphaX: could not allocate chart canvas. Calculations continue. Error ",GetLastError()); warned=true; }
   Destroy(); return false;
  }
  ObjectSetInteger(0,prefix+"Cloud",OBJPROP_BACK,true);
  ObjectSetInteger(0,prefix+"Marks",OBJPROP_BACK,false);
  ObjectSetInteger(0,prefix+"Cloud",OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,prefix+"Marks",OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,prefix+"Cloud",OBJPROP_HIDDEN,true);
  ObjectSetInteger(0,prefix+"Marks",OBJPROP_HIDDEN,true);
  ObjectSetString(0,prefix+"Cloud",OBJPROP_TOOLTIP,"\n");
  ObjectSetString(0,prefix+"Marks",OBJPROP_TOOLTIP,"\n");
  width=w; height=h; ready=true; return true;
 }
 bool XY(const datetime time,const double price,int &x,int &y)
 { return AXValid(price)&&ChartTimePriceToXY(0,0,time,price,x,y); }
 void Band(const int x,const double y1,const double y2,const color clr,const int alpha)
 { cloud.BlendVertical(x,(int)MathCeil(MathMin(y1,y2)),(int)MathFloor(MathMax(y1,y2)),clr,alpha); }
 void Dots(const int x,int y1,int y2,const color clr,const int alpha)
 {
  int top=MathMax(0,MathMin(y1,y2)),bottom=MathMin(height-1,MathMax(y1,y2));
  for(int y=top;y<=bottom;y+=4) marks.PixelSet(x,y,ColorToARGB(clr,(uchar)alpha));
 }
 void TrendLabel(const datetime time,const double price,const bool bull,const AXTheme &t)
 {
  int x,y; if(!XY(time,price,x,y)) return;
  string text=bull?" B U L L ":" B E A R ";
  marks.FontSet("Arial",-85,FW_BOLD);
  int tw=marks.TextWidth(text),th=marks.TextHeight(text),boxY=bull?y+12:y-12-th;
  uint bg=ColorToARGB(bull?t.bull:t.bear,217);
  marks.FillRectangle(x-tw/2-3,boxY-2,x+tw/2+3,boxY+th+2,bg);
  marks.FillTriangle(x,bull?boxY-6:boxY+th+6,x-4,bull?boxY-2:boxY+th+2,
                    x+4,bull?boxY-2:boxY+th+2,bg);
  marks.TextOut(x-tw/2,boxY,text,ColorToARGB(bull?C'26,26,26':clrWhite));
 }
 void Signal(const MqlRates &r,const AXBar &b,const int kind,const bool connector,const AXTheme &t,const double offset)
 {
  bool below=kind==0||kind==3; // long entry / short exit
  double candle=below?r.low:r.high,price=candle+(below?-offset:offset);
  int x,y,cx,cy,endX,endY;
  if(!XY(r.time,price,x,y)) return;
  color clr=kind==0?t.bullBright:kind==1?t.bearBright:t.neutral;
  if(connector&&XY(r.time,candle,cx,cy)&&XY(r.time,price+(below?1:-1)*offset*0.15,endX,endY))
   Dots(x,cy,endY,clr,kind<2?128:102);
  int half=t.size==AX_SIZE_NORMAL?11:t.size==AX_SIZE_SMALL?8:6;
  uint argb=ColorToARGB(clr);
  if(kind<2)
   marks.FillTriangle(x,y+(below?-half:half),x-half,y+(below?half:-half),x+half,y+(below?half:-half),argb);
  else
  {
   half=MathMax(4,half-2);
   marks.LineThick(x-half,y-half,x+half,y+half,argb,2,UINT_MAX,LINE_END_ROUND);
   marks.LineThick(x-half,y+half,x+half,y-half,argb,2,UINT_MAX,LINE_END_ROUND);
  }
 }

public:
 CAlphaXRenderer(void) { ready=false; warned=false; pending=false; width=0; height=0; lastRender=0; }
 bool Pending(void) { return pending; }
 void Init(const string name) { prefix=name; }
 void Destroy(void) { cloud.Destroy(); marks.Destroy(); ready=false; }
 void Draw(const MqlRates &r[],const AXBar &v[],const AXTheme &t,const double atrOffset,const bool force=false)
 {
  int n=ArraySize(r); if(n<1||ArraySize(v)!=n) return;
  ulong now=GetTickCount64(); if(!force&&now-lastRender<100) { pending=true; return; }
  pending=false; lastRender=now;
  int w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0),h=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
  if(w<2||h<2) return;
  if((!ready||w!=width||h!=height)&&!Create(w,h)) return;
  cloud.Erase(0); marks.Erase(0);
  int firstShift=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR,0);
  int visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS,0);
  int left=MathMax(0,n-1-firstShift-1),right=MathMin(n-1,left+visible+3);
  if(t.cloud)
  {
   for(int i=MathMax(1,left);i<=right;i++)
   {
    int x1,ys1,x2,ys2,unused,yf1,yf2,yp1,yp2;
    if(!XY(r[i-1].time,v[i-1].fusionSlow,x1,ys1)||!XY(r[i].time,v[i].fusionSlow,x2,ys2)||
       !XY(r[i-1].time,v[i-1].fusionFast,unused,yf1)||!XY(r[i].time,v[i].fusionFast,unused,yf2)||
       !XY(r[i-1].time,r[i-1].close,unused,yp1)||!XY(r[i].time,r[i].close,unused,yp2)) continue;
    if(x2<=x1) continue;
    color main=v[i].fusionFast>v[i].fusionSlow?t.bull:v[i].fusionFast<v[i].fusionSlow?t.bear:t.neutral;
    int transparencies[5]={72,80,86,91,95};
    for(int x=MathMax(0,x1);x<MathMin(width,x2);x++)
    {
     double f=(double)(x-x1)/(x2-x1),slow=ys1+(ys2-ys1)*f,fast=yf1+(yf2-yf1)*f,price=yp1+(yp2-yp1)*f;
     Band(x,slow,fast,main,89);
     if(!v[i].bullish&&!v[i].bearish) continue;
     for(int layer=0;layer<5;layer++)
     {
      color clr=v[i].bullish?(layer<2?t.bull:t.bullDim):(layer<2?t.bear:t.bearDim);
      int alpha=(int)MathRound(255.0*(100-transparencies[layer])/100.0);
      Band(x,slow+(price-slow)*layer/5.0,slow+(price-slow)*(layer+1)/5.0,clr,alpha);
     }
    }
   }
  }
  if(t.fastEma)
  {
   for(int i=left;i<=right;i++)
   {
    int x,y; if(!XY(r[i].time,v[i].emaFast,x,y)) continue;
    marks.Line(x-2,y,x+2,y,ColorToARGB(t.emaFast));
    marks.Line(x,y-2,x,y+2,ColorToARGB(t.emaFast));
   }
  }
  // Pine has a shared 500-label budget and a default ~50-line budget.
  int labels=0,lines=0;
  for(int i=n-1;i>=left&&(labels<500||lines<50);i--)
  {
   AXBar b=v[i];
   // Reverse of Pine creation order: short exit, long exit, short entry,
   // long entry, bear trend, bull trend. Count even when outside viewport.
   for(int kind=3;kind>=0;kind--)
   {
    bool active=kind==0?b.longEntry:kind==1?b.shortEntry:kind==2?b.longExit:b.shortExit;
    if(!active) continue;
    bool drawLabel=labels<500,drawLine=lines<50; labels++; lines++;
    if(i<=right&&(drawLabel||drawLine)&&AXValid(b.atr))
    {
     // Connectors normally expire before their labels, as in Pine.
     if(drawLabel) Signal(r[i],b,kind,drawLine,t,b.atr*atrOffset);
    }
   }
   if(b.trendBear) { if(labels<500&&i<=right) TrendLabel(r[i].time,r[i].high,false,t); labels++; }
   if(b.trendBull) { if(labels<500&&i<=right) TrendLabel(r[i].time,r[i].low,true,t); labels++; }
  }
  cloud.Update(false); marks.Update(false); ChartRedraw();
 }
};
#endif
