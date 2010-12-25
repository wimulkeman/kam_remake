unit KM_UnitTaskGoOutShowHungry;
{$I KaM_Remake.inc}
interface
uses Classes, KM_Defaults, KM_Units, KromUtils, SysUtils;

  type
    TTaskGoOutShowHungry = class(TUnitTask)
    public
      constructor Create(aUnit:TKMUnit);
      function Execute():TTaskResult; override;
    end;


implementation


{ TTaskGoOutShowHungry }
constructor TTaskGoOutShowHungry.Create(aUnit:TKMUnit);
begin
  Inherited Create(aUnit);
  fTaskName := utn_GoOutShowHungry;
end;


function TTaskGoOutShowHungry.Execute():TTaskResult;
begin
  Result := TaskContinues;
  if fUnit.GetHome.IsDestroyed then begin
    Result := TaskDone;
    exit;
  end;

  with fUnit do
  case fPhase of
    0: begin
         Thought := th_Eat;
         SetActionStay(20,ua_Walk);
       end;
    1: begin
         SetActionGoIn(ua_Walk,gd_GoOutside,fUnit.GetHome);
         GetHome.SetState(hst_Empty);
       end;
    2: SetActionLockedStay(4,ua_Walk);
    3: SetActionGoIn(ua_Walk,gd_GoInside,fUnit.GetHome);
    4: begin
         SetActionStay(20,ua_Walk);
         GetHome.SetState(hst_Idle);
       end;
    else begin
         Thought := th_None;
         Result := TaskDone;
       end;
  end;
  inc(fPhase);
end;


end.
