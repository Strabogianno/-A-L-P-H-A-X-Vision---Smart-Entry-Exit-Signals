// The same cases can run in MQL5 or against the source-shared pure rules in .NET.
void RunPolicyCases()
{
 Check(!AXEExecutionPermission(false,true,true,true,true,true,true,true,true),"master switch also blocks tester execution");
 Check(AXEExecutionPermission(true,true,true,false,false,false,false,false,false),"tester simulation independent of live-terminal permissions");
 Check(AXEExecutionPermission(true,false,false,false,true,true,true,true,true),"permitted demo execution");
 Check(!AXEExecutionPermission(true,false,true,false,true,true,true,true,true),"real account requires separate opt-in");
 Check(AXEExecutionPermission(true,false,true,true,true,true,true,true,true),"permitted real-account opt-in");
 Check(!AXEExecutionPermission(true,false,false,false,false,true,true,true,true),"live terminal permission required");
 Check(!AXEExecutionPermission(true,false,false,false,true,false,true,true,true),"live program permission required");
 Check(!AXEExecutionPermission(true,false,false,false,true,true,false,true,true),"live account permission required");
 Check(!AXEExecutionPermission(true,false,false,false,true,true,true,false,true),"live expert permission required");
 Check(!AXEExecutionPermission(true,false,false,false,true,true,true,true,false),"disconnected terminal cannot execute live");
 Check(AXEEntryDirection(true,false)==1,"long triangle opens long");
 Check(AXEEntryDirection(false,true)==-1,"short triangle opens short");
 Check(AXEEntryDirection(false,false)==0,"trend alone is not an entry");
 Check(AXEEntryDirection(true,true)==0,"contradictory entries blocked");
 Check(AXEExitRequired(1,true,false,1,true,true),"long X closes long");
 Check(!AXEExitRequired(1,false,true,1,true,true),"short X does not close long");
 Check(AXEExitRequired(-1,false,true,-1,true,true),"short X closes short");
 Check(AXEExitRequired(1,false,false,-1,true,true),"bear trend closes long");
 Check(AXEExitRequired(-1,false,false,1,true,true),"bull trend closes short");
 Check(!AXEExitRequired(1,false,false,0,true,true),"neutral does not force exit");
 Check(!AXEExitRequired(1,true,false,-1,false,false),"disabled exit policies honored");
 Check(!AXEExitRequired(0,true,true,1,true,true),"invalid position side ignored");
 Check(AXEEntryAllowed(true,false,false,false,false,true,1,true,true),"flat enabled EA can enter");
 Check(!AXEEntryAllowed(false,false,false,false,false,true,1,true,true),"monitor mode cannot enter");
 Check(!AXEEntryAllowed(true,true,false,false,false,true,1,true,true),"one position limit");
 Check(!AXEEntryAllowed(true,false,true,false,false,true,1,true,true),"foreign exposure blocks entry");
 Check(!AXEEntryAllowed(true,false,false,true,false,true,1,true,true),"pending orders block entry");
 Check(!AXEEntryAllowed(true,false,false,false,true,true,1,true,true),"ambiguous submission blocks entry");
 Check(!AXEEntryAllowed(true,false,false,false,false,false,1,true,true),"stale signal blocked");
 Check(!AXEEntryAllowed(true,false,false,false,false,true,1,false,true),"long toggle honored");
 Check(!AXEEntryAllowed(true,false,false,false,false,true,-1,true,false),"short toggle honored");
 Check(AXEStopDistance(0,0,0.01,10,2)==0,"missing required stop blocks entries");
 Check(Near(AXEStopDistance(0,250,0.01,10,2),2.5),"stop uses MT5 points");
 Check(Near(AXEStopDistance(1,0,0.01,3,2),6),"explicit ATR stop mode");
 Check(AXEStopDistance(1,0,0.01,0,2)==0,"unavailable ATR cannot set stop");
 Check(AXEVolumeFloor(0.009,0.01,100,0.01)==0,"never raise sub-minimum lots");
 Check(AXEVolumeFloor(0.01,0.1,100,0.1)==0,"broker minimum greater than chosen lots");
 Check(Near(AXEVolumeFloor(0.035,0.01,100,0.01),0.03),"volume rounds down");
 Check(Near(AXEVolumeFloor(200,0.01,100,0.01),100),"risk-volume cap");
 Check(AXEVolumeFloor(1,0.01,100,0)==0,"invalid broker lot step rejected");
 Check(Near(AXEPriceGrid(2900.13,0.25,-1),2900),"buy stop rounds down to tick grid");
 Check(Near(AXEPriceGrid(2900.13,0.25,1),2900.25),"sell stop rounds up to tick grid");
 Check(AXEPriceGrid(1,0,-1)==0,"invalid price grid rejected");
 Check(AXEProtectionValid(1,2900.5,2900,2900.5,2898,0,1,0.01),"buy SL without fixed TP");
 Check(!AXEProtectionValid(1,2900.5,2900,2900.5,2899.5,0,1,0.01),"spread counts toward minimum buy SL");
 Check(AXEProtectionValid(-1,2900,2900,2900.5,2902,0,1,0.01),"sell SL without fixed TP");
 Check(!AXEProtectionValid(-1,2900,2900,2900.5,2901,0,1,0.01),"sell SL checked against ask");
 Check(!AXEProtectionValid(1,2900.5,2900,2900.5,2898,2900.6,1,0.01),"TP minimum enforced");
 Check(!AXEProtectionValid(1,2900.5,2900,2900.5,0,0,1,0.01),"no naked entries");
 Check(!AXEProtectionValid(1,2900.5,2901,2900.5,2898,0,1,0.01),"crossed quote rejected");
 Check(AXEFreshBar(100,100,30),"first tick is fresh");
 Check(AXEFreshBar(130,100,30),"entry age boundary inclusive");
 Check(!AXEFreshBar(131,100,30),"late entry not replayed");
 Check(!AXEFreshBar(99,100,30),"clock-inconsistent entry rejected");
 Check(AXEPreflightAccepted(true,0),"documented OrderCheck zero success accepted");
 Check(AXEPreflightAccepted(true,10009),"OrderCheck DONE accepted");
 Check(!AXEPreflightAccepted(false,0),"failed OrderCheck not accepted on zero alone");
 Check(!AXEPreflightAccepted(true,10019),"insufficient funds rejected");
 for(int stepIndex=1;stepIndex<=3;stepIndex++)
 {
  double step=stepIndex==1?0.001:stepIndex==2?0.01:0.1;
  for(int i=1;i<=1000;i++)
  {
   double requested=i*0.00071,volume=AXEVolumeFloor(requested,step,100,step);
   Check(volume<=requested+1.0e-9,"rounded size never exceeds requested size");
   Check(volume==0||volume+1.0e-9>=step,"rounded size never below broker minimum");
   Check(Near(volume/step,MathFloor(volume/step+0.5)),"lot-step alignment");
  }
 }
}
