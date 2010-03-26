unit KM_Units_WorkPlan;
interface
uses KromUtils, KM_Defaults, KM_Terrain, KM_Utils, KM_CommonTypes;

type
  TUnitWorkPlan = class
  private
    fIssued:boolean;
    procedure FillDefaults();
  public
    HasToWalk:boolean;
    Loc:TKMPoint;
    WalkTo:TUnitActionType;
    WorkType:TUnitActionType;
    WorkCyc:integer;
    WorkDir:shortint;
    GatheringScript:TGatheringScript;
    AfterWorkDelay:integer;
    WalkFrom:TUnitActionType;
    Resource1:TResourceType; Count1:byte;
    Resource2:TResourceType; Count2:byte;
    ActCount:byte;
    HouseAct:array[1..32] of record
      Act:THouseActionType;
      TimeToWork:word;
    end;
    Product1:TResourceType; ProdCount1:byte;
    Product2:TResourceType; ProdCount2:byte;
    AfterWorkIdle:integer;
    ResourceDepleted:boolean;
  public
    procedure FindPlan(aUnitType:TUnitType; aHome:THouseType; aProduct:TResourceType; aLoc:TKMPoint);
    property IsIssued:boolean read fIssued;
    procedure Save(SaveStream:TKMemoryStream);
    procedure Load(LoadStream:TKMemoryStream);
  end;

implementation

{Houses are only a place on map, they should not issue or perform tasks (except Training)
Everything should be issued by units
Where to go, which walking style, what to do on location, for how long
How to go back in case success, incase bad luck
What to take from supply, how much, take2, much2
What to do, Work/Cycles, What resource to add to Output, how much
E.g. CoalMine: Miner arrives at home and Idles for 5sec, then takes a work task (depending on ResOut count)
Since Loc is 0,0 he immidietely skips to Phase X where he switches house to Work1 (and self busy for same framecount)
Then Work2 and Work3 same way. Then adds resource to out and everything to Idle for 5sec.
E.g. Farmer arrives at home and Idles for 5sec, then takes a work task (depending on ResOut count, HouseType and Need to sow corn)
...... then switches house to Work1 (and self busy for same framecount)
Then Work2 and Work3 same way. Then adds resource to out and everything to Idle for 5sec.}
procedure TUnitWorkPlan.FillDefaults();
begin
  fIssued:=true;
  HasToWalk:=false;
  Loc:=KMPoint(0,0);
  WalkTo:=ua_Walk;
  WorkType:=ua_Work;
  WorkCyc:=0;
  WorkDir:=0;
  GatheringScript:=gs_None;
  AfterWorkDelay:=0;
  WalkFrom:=ua_Walk;
  Resource1:=rt_None; Count1:=0;
  Resource2:=rt_None; Count2:=0;
  ActCount:=0;
  Product1:=rt_None; ProdCount1:=0;
  Product2:=rt_None; ProdCount2:=0;
  AfterWorkIdle:=0;
  ResourceDepleted:=false;
end;

procedure TUnitWorkPlan.FindPlan(aUnitType:TUnitType; aHome:THouseType; aProduct:TResourceType; aLoc:TKMPoint);
  procedure WalkStyle(aLoc2:TKMPoint; aTo,aWork:TUnitActionType; aCycles,aDelay:byte; aFrom:TUnitActionType; aScript:TGatheringScript; aWorkDir:shortint=-1); overload;
  begin
    Loc:=aLoc2;
    HasToWalk:=true;
    WalkTo:=aTo;
    WorkType:=aWork;
    WorkCyc:=aCycles;
    AfterWorkDelay:=aDelay;
    GatheringScript:=aScript;
    WalkFrom:=aFrom;
    WorkDir:=aWorkDir;
  end;
  procedure SubActAdd(aAct:THouseActionType; aCycles:single);
  begin
    inc(ActCount); HouseAct[ActCount].Act:=aAct;
    HouseAct[ActCount].TimeToWork:=round(HouseDAT[byte(aHome)].Anim[byte(aAct)].Count * aCycles);
  end;
  procedure ResourcePlan(Res1:TResourceType; Qty1:byte; Res2:TResourceType; Qty2:byte; Prod1:TResourceType; Prod2:TResourceType=rt_None);
  begin
    Resource1:=Res1; Count1:=Qty1;
    Resource2:=Res2; Count2:=Qty2;
    Product1:=Prod1; ProdCount1:=HouseDAT[byte(aHome)].ResProductionX;
    if Prod2=rt_None then exit;
    Product2:=Prod2; ProdCount2:=HouseDAT[byte(aHome)].ResProductionX;
  end;
  var i:integer; TempLocDir: TKMPointDir;
begin
FillDefaults;
AfterWorkIdle := HouseDAT[byte(aHome)].WorkerRest*10;

//Now we need to fill only specific properties
if (aUnitType=ut_LamberJack)and(aHome=ht_SawMill) then begin
  ResourcePlan(rt_Trunk,1,rt_None,0,rt_Wood);
  SubActAdd(ha_Work1,1);
  SubActAdd(ha_Work2,25);
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Miner)and(aHome=ht_CoalMine) then begin
  if fTerrain.FindOre(aLoc,rt_Coal).X<>0 then begin
    Loc:=fTerrain.FindOre(aLoc,rt_Coal);
    ResourcePlan(rt_None,0,rt_None,0,rt_Coal);
    GatheringScript:=gs_CoalMiner;
    SubActAdd(ha_Work1,1);
    SubActAdd(ha_Work2,23);
    SubActAdd(ha_Work5,1);
  end else
  begin
    fIssued:=false;
    ResourceDepleted:=true;
  end;
end else
if (aUnitType=ut_Miner)and(aHome=ht_IronMine) then begin
  if fTerrain.FindOre(aLoc,rt_IronOre).X<>0 then begin
    Loc:=fTerrain.FindOre(aLoc,rt_IronOre);
    ResourcePlan(rt_None,0,rt_None,0,rt_IronOre);
    GatheringScript:=gs_IronMiner;
    SubActAdd(ha_Work1,1);
    SubActAdd(ha_Work2,24);
    SubActAdd(ha_Work5,1);
  end else
  begin
    fIssued:=false;
    ResourceDepleted:=true;
  end;
end else
if (aUnitType=ut_Miner)and(aHome=ht_GoldMine) then begin
  if fTerrain.FindOre(aLoc,rt_GoldOre).X<>0 then begin
    Loc:=fTerrain.FindOre(aLoc,rt_GoldOre);
    ResourcePlan(rt_None,0,rt_None,0,rt_GoldOre);
    GatheringScript:=gs_GoldMiner;
    SubActAdd(ha_Work1,1);
    SubActAdd(ha_Work2,24);
    SubActAdd(ha_Work5,1);
  end else
  begin
    fIssued:=false;
    ResourceDepleted:=true;
  end;
end else
if (aUnitType=ut_Metallurgist)and(aHome=ht_IronSmithy) then begin
  ResourcePlan(rt_IronOre,1,rt_Coal,1,rt_Steel);
  for i:=1 to 4 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
  end;
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,0.25);
end else
if (aUnitType=ut_Metallurgist)and(aHome=ht_Metallurgists) then begin
  ResourcePlan(rt_GoldOre,1,rt_Coal,1,rt_Gold);
  for i:=1 to 4 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,0.1);
end else
if (aUnitType=ut_Smith)and(aHome=ht_ArmorSmithy)and(aProduct=rt_MetalArmor) then begin
  ResourcePlan(rt_Steel,1,rt_Coal,1,rt_MetalArmor);
  for i:=1 to 4 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Smith)and(aHome=ht_ArmorSmithy)and(aProduct=rt_MetalShield) then begin
  ResourcePlan(rt_Steel,1,rt_Coal,1,rt_MetalShield);
  for i:=1 to 4 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Smith)and(aHome=ht_WeaponSmithy)and(aProduct=rt_Sword) then begin
  ResourcePlan(rt_Steel,1,rt_Coal,1,rt_Sword);
  SubActAdd(ha_Work1,1);
  for i:=1 to 3 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Smith)and(aHome=ht_WeaponSmithy)and(aProduct=rt_Hallebard) then begin
  ResourcePlan(rt_Steel,1,rt_Coal,1,rt_Hallebard);
  SubActAdd(ha_Work1,1);
  for i:=1 to 3 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Smith)and(aHome=ht_WeaponSmithy)and(aProduct=rt_Arbalet) then begin
  ResourcePlan(rt_Steel,1,rt_Coal,1,rt_Arbalet);
  SubActAdd(ha_Work1,1);
  for i:=1 to 3 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Lamberjack)and(aHome=ht_ArmorWorkshop)and(aProduct=rt_Armor) then begin
  ResourcePlan(rt_Leather,1,rt_None,0,rt_Armor);
  for i:=1 to 4 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work2,0.25);
end else
if (aUnitType=ut_Lamberjack)and(aHome=ht_ArmorWorkshop)and(aProduct=rt_Shield) then begin
  ResourcePlan(rt_Wood,1,rt_None,0,rt_Shield);
  for i:=1 to 4 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work2,0.25);
end else
if (aUnitType=ut_Lamberjack)and(aHome=ht_WeaponWorkshop)and(aProduct=rt_Axe) then begin
  ResourcePlan(rt_Wood,2,rt_None,0,rt_Axe);
  SubActAdd(ha_Work1,1);
  for i:=1 to 3 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Lamberjack)and(aHome=ht_WeaponWorkshop)and(aProduct=rt_Pike) then begin
  ResourcePlan(rt_Wood,2,rt_None,0,rt_Pike);
  SubActAdd(ha_Work1,1);
  for i:=1 to 3 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Lamberjack)and(aHome=ht_WeaponWorkshop)and(aProduct=rt_Bow) then begin
  ResourcePlan(rt_Wood,2,rt_None,0,rt_Bow);
  SubActAdd(ha_Work1,1);
  for i:=1 to 3 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
    SubActAdd(ha_Work4,1);
  end;
  SubActAdd(ha_Work5,1);
end else
if (aUnitType=ut_Baker)and(aHome=ht_Mill) then begin
  ResourcePlan(rt_Corn,1,rt_None,0,rt_Flour);
  SubActAdd(ha_Work2,47);
end else
if (aUnitType=ut_Baker)and(aHome=ht_Bakery) then begin
  ResourcePlan(rt_Flour,1,rt_None,0,rt_Bread);
  for i:=1 to 7 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work3,1);
  end;
end else
if (aUnitType=ut_Farmer)and(aHome=ht_Farm) then begin
  if ((fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,false).X=0) and (fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,true).X<>0)) or
     ((fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,true).X<>0) and (fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,false).X<>0) and (Random(2) = 1)) then begin
    ResourcePlan(rt_None,0,rt_None,0,rt_Corn);
    WalkStyle(fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,true),ua_WalkTool,ua_Work,6,0,ua_WalkBooty,gs_FarmerCorn);
  end else
  if fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,false).X<>0 then
    WalkStyle(fTerrain.FindField(aLoc,RANGE_FARMER,ft_Corn,false),ua_Walk,ua_Work1,10,0,ua_Walk,gs_FarmerSow)
  else
    fIssued:=false;
end else
if (aUnitType=ut_Farmer)and(aHome=ht_Wineyard) then begin
  if fTerrain.FindField(aLoc,RANGE_FARMER,ft_Wine,true).X<>0 then begin
    ResourcePlan(rt_None,0,rt_None,0,rt_Wine);
    WalkStyle(fTerrain.FindField(aLoc,RANGE_FARMER,ft_Wine,true),ua_WalkTool2,ua_Work2,5,0,ua_WalkBooty2,gs_FarmerWine,0); //Grapes must always be picked facing up
    SubActAdd(ha_Work1,1);
    SubActAdd(ha_Work2,11);
    SubActAdd(ha_Work5,1);
  end else
    fIssued:=false;
end else
if (aUnitType=ut_StoneCutter)and(aHome=ht_Quary) then begin
  if fTerrain.FindStone(aLoc,RANGE_STONECUTTER).X<>0 then begin
    ResourcePlan(rt_None,0,rt_None,0,rt_Stone);
    WalkStyle(fTerrain.FindStone(aLoc,RANGE_STONECUTTER),ua_Walk,ua_Work,8,0,ua_WalkTool,gs_StoneCutter,0);
    SubActAdd(ha_Work1,1);
    SubActAdd(ha_Work2,9);
    SubActAdd(ha_Work5,1);
  end else
  begin
    fIssued:=false;
    ResourceDepleted:=true;
  end;
end else
if (aUnitType=ut_WoodCutter)and(aHome=ht_Woodcutters) then begin
  TempLocDir := fTerrain.FindTree(aLoc,RANGE_WOODCUTTER);
  if TempLocDir.Loc.X<>0 then begin
    ResourcePlan(rt_None,0,rt_None,0,rt_Trunk);
    WalkStyle(KMPoint(TempLocDir),ua_WalkBooty,ua_Work,15,20,ua_WalkTool2,gs_WoodCutterCut,TempLocDir.Dir);
  end else
  if fTerrain.FindPlaceForTree(aLoc,RANGE_WOODCUTTER).X<>0 then
    //In some unit defines plant is ua_Work1, in others it is ua_Work?
    //Dunno, but see KM_ResourceGFX line 406:407 for the explanation of the case
    WalkStyle(fTerrain.FindPlaceForTree(aLoc,RANGE_WOODCUTTER),ua_WalkTool,ua_Work1,12,0,ua_Walk,gs_WoodCutterPlant,0)
  else
    fIssued:=false;
end else
if (aUnitType=ut_Butcher)and(aHome=ht_Tannery) then begin
  ResourcePlan(rt_Skin,1,rt_None,0,rt_Leather);
  SubActAdd(ha_Work1,1);
  SubActAdd(ha_Work2,29);
end else
if (aUnitType=ut_Butcher)and(aHome=ht_Butchers) then begin
  ResourcePlan(rt_Pig,1,rt_None,0,rt_Sausages);
  SubActAdd(ha_Work1,1);
  for i:=1 to 6 do begin
    SubActAdd(ha_Work2,1);
    SubActAdd(ha_Work4,1);
    SubActAdd(ha_Work3,1);
  end;
end else
if (aUnitType=ut_AnimalBreeder)and(aHome=ht_Swine) then begin
  ResourcePlan(rt_Corn,1,rt_None,0,rt_Pig,rt_Skin);
  GatheringScript:=gs_SwineBreeder;
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,1);
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,1);
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,1);
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,1);
  SubActAdd(ha_Work2,1);
end else 
if (aUnitType=ut_AnimalBreeder)and(aHome=ht_Stables) then begin
  ResourcePlan(rt_Corn,1,rt_None,0,rt_Horse);
  GatheringScript:=gs_HorseBreeder;
  SubActAdd(ha_Work1,1);
  SubActAdd(ha_Work2,1);
  SubActAdd(ha_Work3,1);
  SubActAdd(ha_Work4,1);
  SubActAdd(ha_Work5,1);
end else

if (aUnitType=ut_Fisher)and(aHome=ht_FisherHut) then begin
  TempLocDir := fTerrain.FindFishWater(aLoc,RANGE_FISHERMAN);
  if TempLocDir.Loc.X<>0 then begin
    ResourcePlan(rt_None,0,rt_None,0,rt_Fish);
    WalkStyle(KMPoint(TempLocDir),ua_Walk,ua_Work2,12,0,ua_WalkTool,gs_FisherCatch,TempLocDir.Dir);
  end else
  begin
    fIssued:=false;
    ResourceDepleted:=true;
  end;
end else
if (aUnitType=ut_Recruit)and(aHome=ht_Barracks) then begin
  fIssued:=false; //Let him idle
end else
if (aUnitType=ut_Recruit)and(aHome=ht_WatchTower) then begin
  fIssued:=false; //Let him idle
end else
  fLog.AssertToLog(false,'There''s yet no working plan for '+TypeToString(aUnitType)+' in '+TypeToString(aHome));
end;


procedure TUnitWorkPlan.Load(LoadStream:TKMemoryStream);
var i:integer; s:string;
begin
  LoadStream.Read(s); if s <> 'WorkPlan' then exit;
  LoadStream.Read(fIssued);
//public
  LoadStream.Read(HasToWalk);
  LoadStream.Read(Loc);
  LoadStream.Read(WalkTo, SizeOf(WalkTo));
  LoadStream.Read(WorkType, SizeOf(WorkType));
  LoadStream.Read(WorkCyc);
  LoadStream.Read(WorkDir, SizeOf(WorkDir));
  LoadStream.Read(GatheringScript, SizeOf(GatheringScript));
  LoadStream.Read(AfterWorkDelay);
  LoadStream.Read(WalkFrom, SizeOf(WalkFrom));
  LoadStream.Read(Resource1, SizeOf(Resource1));
  LoadStream.Read(Count1);
  LoadStream.Read(Resource2, SizeOf(Resource2));
  LoadStream.Read(Count2);
  LoadStream.Read(ActCount);
  for i:=1 to ActCount do //Write only assigned
  begin
    LoadStream.Read(HouseAct[i].Act, SizeOf(HouseAct[i].Act));
    LoadStream.Read(HouseAct[i].TimeToWork, SizeOf(HouseAct[i].TimeToWork));
  end;
  LoadStream.Read(Product1, SizeOf(Product1));
  LoadStream.Read(ProdCount1);
  LoadStream.Read(Product2, SizeOf(Product2));
  LoadStream.Read(ProdCount2);
  LoadStream.Read(AfterWorkIdle);
  LoadStream.Read(ResourceDepleted);
end;

  
procedure TUnitWorkPlan.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  SaveStream.Write('WorkPlan');
  SaveStream.Write(fIssued);
//public
  SaveStream.Write(HasToWalk);
  SaveStream.Write(Loc);
  SaveStream.Write(WalkTo, SizeOf(WalkTo));
  SaveStream.Write(WorkType, SizeOf(WorkType));
  SaveStream.Write(WorkCyc);
  SaveStream.Write(WorkDir, SizeOf(WorkDir));
  SaveStream.Write(GatheringScript, SizeOf(GatheringScript));
  SaveStream.Write(AfterWorkDelay);
  SaveStream.Write(WalkFrom, SizeOf(WalkFrom));
  SaveStream.Write(Resource1, SizeOf(Resource1));
  SaveStream.Write(Count1);
  SaveStream.Write(Resource2, SizeOf(Resource2));
  SaveStream.Write(Count2);
  SaveStream.Write(ActCount);
  for i:=1 to ActCount do //Write only assigned
  begin
    SaveStream.Write(HouseAct[i].Act, SizeOf(HouseAct[i].Act));
    SaveStream.Write(HouseAct[i].TimeToWork, SizeOf(HouseAct[i].TimeToWork));
  end;
  SaveStream.Write(Product1, SizeOf(Product1));
  SaveStream.Write(ProdCount1);
  SaveStream.Write(Product2, SizeOf(Product2));
  SaveStream.Write(ProdCount2);
  SaveStream.Write(AfterWorkIdle);
  SaveStream.Write(ResourceDepleted);
end;

end.
