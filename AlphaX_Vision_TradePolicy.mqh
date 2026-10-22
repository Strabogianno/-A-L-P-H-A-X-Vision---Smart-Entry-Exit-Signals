// Pure execution rules, independent of terminal/account access.
#ifndef ALPHAX_VISION_TRADEPOLICY_MQH
#define ALPHAX_VISION_TRADEPOLICY_MQH
bool AXEFinite(double x) { return x>-1.0e100 && x<1.0e100; }
bool AXEExecutionPermission(bool enabled,bool tester,bool realAccount,bool allowReal,
 bool terminalPermission,bool programPermission,bool accountPermission,bool expertPermission,bool connected)
{
 if(!enabled) return false;
 if(tester) return true; // Broker simulation still validates each OrderCheck.
 return (!realAccount||allowReal)&&terminalPermission&&programPermission&&accountPermission&&expertPermission&&connected;
}
int AXEEntryDirection(bool longEntry,bool shortEntry)
{
 if(longEntry==shortEntry) return 0;
 return longEntry?1:-1;
}
bool AXEExitRequired(int side,bool longExit,bool shortExit,int trend,bool onExit,bool onFlip)
{
 if(side!=1 && side!=-1) return false;
 return (onExit && (side==1?longExit:shortExit)) || (onFlip && trend==-side);
}
bool AXEEntryAllowed(bool enabled,bool ownPosition,bool foreignPosition,bool pendingOrder,
 bool uncertain,bool fresh,int side,bool allowLong,bool allowShort)
{
 return enabled && !ownPosition && !foreignPosition && !pendingOrder && !uncertain && fresh &&
        ((side==1 && allowLong)||(side==-1 && allowShort));
}
double AXEPriceGrid(double price,double tick,int roundDirection)
{
 if(!AXEFinite(price)||!AXEFinite(tick)||price<=0||tick<=0) return 0;
 double units=price/tick;
 return (roundDirection<0?MathFloor(units+1.0e-9):MathCeil(units-1.0e-9))*tick;
}
double AXEVolumeFloor(double requested,double minimum,double maximum,double step)
{
 if(!AXEFinite(requested)||!AXEFinite(minimum)||!AXEFinite(maximum)||!AXEFinite(step)||
    requested<minimum||minimum<=0||maximum<minimum||step<=0) return 0;
 double volume=MathFloor(MathMin(requested,maximum)/step+1.0e-9)*step;
 return volume+1.0e-9>=minimum?volume:0;
}
double AXEStopDistance(int mode,double points,double point,double atr,double multiplier)
{
 if(mode==0) return AXEFinite(points)&&AXEFinite(point)&&points>0&&point>0?points*point:0;
 return AXEFinite(atr)&&AXEFinite(multiplier)&&atr>0&&multiplier>0?atr*multiplier:0;
}
bool AXEProtectionValid(int side,double entry,double bid,double ask,double sl,double tp,double minimum,double tick)
{
 if(!AXEFinite(entry)||!AXEFinite(bid)||!AXEFinite(ask)||!AXEFinite(sl)||!AXEFinite(tp)||
    !AXEFinite(minimum)||!AXEFinite(tick)||entry<=0||bid<=0||ask<bid||sl<=0||tp<0||minimum<0||tick<=0) return false;
 double tolerance=tick*1.0e-6;
 if(side==1) return sl<entry && sl<bid && bid-sl+tolerance>=minimum &&
                     (tp==0||(tp>entry&&tp-bid+tolerance>=minimum));
 if(side==-1) return sl>entry && sl>ask && sl-ask+tolerance>=minimum &&
                      (tp==0||(tp<entry&&ask-tp+tolerance>=minimum));
 return false;
}
bool AXEFreshBar(long now,long currentOpen,int maximumDelay)
{ return maximumDelay>=0&&now>=currentOpen&&now-currentOpen<=maximumDelay; }
bool AXEPreflightAccepted(bool checkPassed,int returnCode)
{ return checkPassed&&(returnCode==0||returnCode==10009); }
#endif
