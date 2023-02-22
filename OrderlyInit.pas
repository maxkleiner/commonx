unit OrderlyInit;
{x$DEFINE LOG_UNIT_INIT}

{$INCLUDE DelphiDefs.inc}
{$MESSAGE '*******************COMPILING OrderlyInit.pas'}
{$D+}
{x$DEFINE DEBUG_INIT}
{x$DEFINE OI_NOCHECK}
interface

uses
  typex, systemx, stringx,debug, classes, betterobject, sysutils;
const
  LOCAL_DEPENDENCIES = '';
type
  TInitProc = procedure;
  TOrderlyInitializer = class;//forward

  TPair = record
    ord: TOrderlyInitializer;
    name: string;
{$IFDEF ALLOW_ANON_INIT}
    Anoninit: TProc;
    AnonFinal: TProc;
{$ENDIF}
    init: TInitProc;
    AfterInit: TInitProc;
    prefinalize: TInitProc;
    finalize: TInitProc;
    late_finalize: TInitProc;
    dependencies: string;
    cs_dependencies: string;
    initialized: boolean;
    afterinitcalled: boolean;
    finalized: boolean;
    waiting_for_dependent_initialization:boolean;
    initorder: nativeint;
    function HasDependency(sName: string): boolean;
    procedure DoInit;

    function DependenciesMet: boolean;
    function WasDependedOn: boolean;
    procedure StartDependents;
    function AllDependenciesAvailable: boolean;


  end;

  PPair = ^TPair;

  TOrderlyInitializer = class
  private
    function GEtProc(idx: nativeint): PPair;
    procedure SetInitialized(const Value: boolean);
    function GetUnitByName(sName: string): PPair;
  protected
    didAfterInit: boolean;
    Finitialized: boolean;
    FProcs: array of TPair;
    FRequiredUnits, FmetRequirements: TStringlist;
    procedure FinalizeProcs;
    procedure PreFinalizeProcs;
    procedure AfterinitProcs;
    procedure LateFinalizeProcs;
    procedure RememberRequiredUnits(s: string);
  public
    initcounter: nativeint;
    property Initialized: boolean read Finitialized write SetInitialized;
    constructor Create;virtual;
    destructor Destroy;override;
    function IndexOfUnit(sNAme: string): nativeint;
    function HasUnit(sName: string): boolean;
    property unitByName[sname: string]: PPair read GetUnitByName;
    function RegisterProcs(name: string; init, finalize: TInitProc; sDependenciesSeparatedByCommas: string = ''): PPair;overload;
    function RegisterProcs(name: string; init, prefinalize, finalize, late_finalize: TInitProc; sDependenciesSeparatedByCommas: string = ''): PPair;overload;
    function RegisterProcs(name: string; init, afterinit, prefinalize, finalize,late_finalize: TInitProc; sDependenciesSeparatedByCommas: string = ''): PPair;overload;

    function RegisterProcs(name: string; anoninit, anonfinal: TProc; init, afterinit, prefinalize, finalize,late_finalize: TInitProc; sDependenciesSeparatedByCommas: string = ''): PPair;overload;
{$IFDEF ALLOW_ANON_INIT}
    function RegisterProcs(name: string; anoninit, anonfinal: TProc; sDependenciesSeparatedByCommas: string = ''): PPair;overload;
{$ENDIF}

    property Procs[idx: nativeint]: PPair read GEtProc;
    function Count: nativeint;
    function CheckAllMet: boolean;
    procedure CheckAllMetFatal;
    function GetUninitializedUnits: string;
    function GetUnmetRequirements: string;
    procedure DoAfterInit;
    procedure DLLInit;

  end;




procedure ConsoleDebug(s: string);
function init: TOrderlyInitializer;
procedure InitShutdown;

implementation



{$IFDEF WINDOWS}
uses
  windows;
{$ENDIF}
  {miscroutines, stringutilities,shareddebuglog,sysutils;}

{ TOrderlyInitializer }

var
  ginit: TOrderlyInitializer = nil;


procedure TOrderlyInitializer.AfterinitProcs;
var
  t,u: integer;
  p: PPair;
begin
  for t:= count-1 downto 0 do begin
    for u := count-1 downto 0 do begin
      p := @FProcs[u];
      if p.initorder = t then begin
        if not p.finalized then begin
          if (@p.Afterinit) <> nil then begin
            ConsoleDebug(extractfilename(DLLName)+': AfterInit '+p.name);
            p.AfterInit();
            ConsoleDebug(extractfilename(DLLName)+': AfterInit - Done '+p.name);
          end;
        end;
      end;

    end;
  end;

end;


function TOrderlyInitializer.CheckAllMet: boolean;
var
  t: fi;
begin
  DoAfterInit;
  result := true;
  var initcount := 1;
  while initcount > 0  do begin
    initcount := 0;
    result := true;
  for t:= 0 to Self.Count-1 do begin
    if not procs[t].initialized then begin
{$IFDEF DEBUG_INIT}      Debug.Log('Checking Dependencies for '+procs[t].name);{$ENDIF}
      if Procs[t].AllDependenciesAvailable then begin
        if procs[t].DependenciesMet then begin
          procs[t].doinit;
          inc(initcount);
        end;
      end;
      if not procs[t].initialized then begin
{$IFDEF DEBUG_INIT}
{$IFDEF LOG_UNIT_INIT}
        Debug.Log('**'+procs[t].name+' is still not initialized because:');
{$ENDIF}
        var slh := ParseStringh(procs[t].cs_dependencies, ',');
        for var y := 0 to slh.o.Count-1 do begin
          var dep := slh.o[y];
          if not HasUnit(dep) then begin
            ConsoleDebug('****'+dep+' not yet registered');
          end else
          if unitbyname[dep].initialized then begin
            ConsoleDebug('****'+dep+' not initialized');
          end;
        end;
        Debug.Log('*******************************************');



{$ENDIF}

        result := false;
      end;
    end;
  end;
  end;

  initialized := result;
{$IFDEF LOG_UNIT_INIT}
  debug.Log('finished checkallmet');
{$ENDIF}
end;

procedure TOrderlyInitializer.CheckAllMetFatal;
begin
  if not init.CheckAllMet then begin
    raise ECritical.create('Units are still uninitialized: '+init.GetUninitializedUnits+' which require '+GEtUnmetREquirements);
  end;
end;

function TOrderlyInitializer.Count: nativeint;
begin
  result := length(FProcs);
end;

constructor TOrderlyInitializer.Create;
begin
  inherited Create;
  FRequiredUnits := TStringlist.create;
  FMetRequirements := TStringlist.create;
{$IFDEF WINDOWS}
  OutputDebugSTring('Creating OrderlyInitializer');
{$ENDIF}
end;

destructor TOrderlyInitializer.Destroy;
begin
  prefinalizeprocs;
  finalizeprocs;
  latefinalizeprocs;
  FRequiredUnits.Free;
  FrequiredUnits := nil;
  FMetRequirements.free;
  FMetREquirements := nil;
  inherited;
end;

procedure TOrderlyInitializer.DLLInit;
begin
  checkAllMet;
  checkAllMetFatal;

end;

procedure TOrderlyInitializer.DoAfterInit;
begin
  if didafterinit then
    exit;
  didafterinit := true;

  AfterinitProcs;
end;

procedure TOrderlyInitializer.FinalizeProcs;

var
  t,u: integer;
  p: PPair;
begin
  for t:= count-1 downto 0 do begin
    for u := count-1 downto 0 do begin
      p := @FProcs[u];
      if p.initorder = t then begin
        ConsoleDebug(extractfilename(DLLName)+': Finalize '+p.name);
        if not p.finalized then begin
          p.finalized := true;
          if assigned(p.finalize) then
            p.Finalize();
{$IFDEF ALLOW_ANON_INIT}
          if assigned(p.AnonFinal) then
            p.AnonFinal();
{$ENDIF}
        end;
      end;
    end;
  end;

end;

function TOrderlyInitializer.GEtProc(idx: nativeint): PPair;
begin
  result := @FProcs[idx];
end;

function TOrderlyInitializer.GetUninitializedUnits: string;
var
  t: ni;
begin
  result := '';
  for t := 0 to count-1 do begin
    if not procs[t].Initialized then
      result := result + procs[t].name+' ';
  end;

end;

function TOrderlyInitializer.GetUnitByName(sName: string): PPair;
begin
  result := procs[indexofunit(sName)];
end;

function TOrderlyInitializer.GetUnmetRequirements: string;
var
  t: ni;
  s: string;
begin
  result := '';
  for t:= 0 to FRequiredUnits.count-1 do begin
    s := FrequiredUnits[t];
    if FmetRequirements.IndexOf(s) < 0 then begin
      if result <> '' then
        result := result + ', ';

      result := result + s;
    end;

  end;



end;

function TOrderlyInitializer.HasUnit(sName: string): boolean;
begin
  result := IndexOfUnit(sName) >= 0;
end;


function TOrderlyInitializer.IndexOfUnit(sNAme: string): nativeint;
var
  t: integer;
begin
  result := -1;
  for t:= 0 to count-1 do begin
    if lowercase(FProcs[t].Name) = lowercase(sName) then begin
      result := t;
      break;
    end;
  end;
end;


procedure TOrderlyInitializer.LateFinalizeProcs;
var
  t,u: integer;
  p: PPair;
begin
  for t:= count-1 downto 0 do begin
    for u := count-1 downto 0 do begin
      p := @FProcs[u];
      if p.initorder = t then begin
        if (@p.late_finalize) <> nil then begin
          ConsoleDebug(extractfilename(DLLName)+': LateFinalize '+p.name);
          p.late_finalize();
          ConsoleDebug(extractfilename(DLLName)+': LateFinalize - Done '+p.name);
        end;
      end;
    end;
  end;
end;
procedure TOrderlyInitializer.PreFinalizeProcs;
var
  t,u: integer;
  p: PPair;
begin
  for t:= count-1 downto 0 do begin
    for u := count-1 downto 0 do begin
      p := @FProcs[u];
      if p.initorder = t then begin
        if not p.finalized then begin
          if (@p.prefinalize) <> nil then begin
            ConsoleDebug(extractfilename(DLLName)+': PreFinalize '+p.name);
            p.PreFinalize();
            ConsoleDebug(extractfilename(DLLName)+': PreFinalize - Done '+p.name);
          end;
        end;
      end;

    end;
  end;

end;



function TOrderlyInitializer.RegisterProcs(name: string; init,
  finalize: TInitProc; sDependenciesSeparatedByCommas: string): PPair;
begin
{$IFDEF LOG_UNIT_INIT}
  Debug.Log('call contains latefinalize');
{$ENDIF}
  result := RegisterProcs(name, init, nil, finalize, nil, sDependenciesSeparatedByCommas);
end;

function TOrderlyInitializer.RegisterProcs(name: string; init, prefinalize, finalize, late_finalize: TInitProc; sDependenciesSeparatedByCommas: string = ''): PPair;
begin
  result := RegisterProcs(name, init, nil, prefinalize, finalize, late_finalize, sDependenciesSeparatedByCommas);
end;

function TOrderlyInitializer.RegisterProcs(name: string; init, afterinit, prefinalize, finalize, late_finalize: TInitProc; sDependenciesSeparatedByCommas: string = ''): PPair;
begin
  result := RegisterProcs(name, nil,nil, init, afterinit, prefinalize, finalize, late_finalize,sDependenciesSeparatedByCommas);

end;


procedure TOrderlyInitializer.RememberRequiredUnits(s: string);
var
  sl: IHolder<TStringlist>;
  t: ni;
  ss: string;
begin
  sl := ParseStringH(s, ']');

  for t:= 0 to sl.o.count-1 do begin
    ss := sl.o[t];
    ss := StringReplace(ss, '[', '', [rfReplaceAll]);
    ss := StringReplace(ss, ']', '', [rfReplaceAll]);
    if ss <> '' then begin
      if FRequiredUnits.IndexOf(ss) < 0 then begin
        FRequiredUnits.add(lowercase(ss));
      end;
    end;



  end;


end;

procedure TOrderlyInitializer.SetInitialized(const Value: boolean);
begin
  Finitialized := Value;
{$IFDEF LOG_UNIT_INIT}
  if value then
    Debug.Log(self,'OrderlyInit.INITIALIZED!************************');
{$ENDIF}


end;


function init: TOrderlyInitializer;
begin
  if ginit = nil then
    ginit := TOrderlyInitializer.create;

  result := gInit;
end;

{$IFDEF ALLOW_ANON_INIT}
function TOrderlyInitializer.RegisterProcs(name: string; anoninit,
  anonfinal: TProc; sDependenciesSeparatedByCommas: string): PPair;
begin
  result := RegisterProcs(name, anoninit, anonfinal, nil, nil, nil, nil, nil,  sDependenciesSeparatedByCommas);

end;
{$ENDIF}


function TOrderlyInitializer.RegisterProcs(name: string; anoninit,
  anonfinal: TProc; init, afterinit, prefinalize, finalize,
  late_finalize: TInitProc; sDependenciesSeparatedByCommas: string): PPair;
var
  s1,s2: string;
  bAllStarted: boolean;
begin
{$IFDEF DEBUG_INIT}
  Debug.Log(extractfilename(DLLName)+': Registering '+name);
{$ENDIF}
{$IFDEF LOG_UNIT_INIT}
  if assigned(late_finalize) then
    Debug.Log('contains latefinalize');
{$ENDIF}

  if @afterinit <> nil then begin
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('Use of AfterInit is not recommended because the only way to know when all Inits are complete is to manually call init.DoAfterInit (which is also called by CheckAllMet().  It cannot be guaranteed that every app will remember to do that.');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');
    Debug.Log('*********** NOTE NOTE NOTE NOTE NOTE*****');

  end;
  Initialized := false;//<<----- since we're adding new units, we are no longer initialized
  //add an entry to the list
  setlength(FProcs, length(FProcs)+1);

  result := @FProcs[high(FProcs)];
  result.ord := self;
  result.initorder := -1;

  result.name := name;
  result.init := init;
{$IFDEF ALLOW_ANON_INIT}
  result.Anoninit := anoninit;
  result.AnonFinal := anonfinal;
{$ENDIF}
  result.afterinit := afterInit;
  result.finalize := finalize;
  result.prefinalize := prefinalize;
  result.late_finalize := late_finalize;


  //record the dependencies for the unit and also check to see if each dependency
  //has been started
  bAllStarted := true;//<--default all started flag
  if LOCAL_DEPENDENCIES <> '' then begin
    if sDependenciesSeparatedByCommas = '' then
        sDependenciesSeparatedByCommas := LOCAL_DEPENDENCIES
    else
      sDependenciesSeparatedByCommas := LOCAL_DEPENDENCIES+','+sDependenciesSeparatedByCommas;
  end;

  result.cs_dependencies := '';
  s1 := '';
  s2 := sDependenciesSeparatedByCommas;
  s2 := StringReplace(s2, ' ', '', [rfReplaceAll]);
  while SplitString(s2, ',', s1,s2) do begin
    if lowercase(s1) <> lowercase(result.name) then begin
      result.dependencies := result.dependencies + '['+lowercase(s1)+']';
      if result.cs_dependencies = '' then
        result.cs_dependencies := lowercase(s1)
      else
        result.cs_dependencies := result.cs_dependencies + ','+lowercase(s1);
      if not self.HasUnit(s1) then begin
        bAllStarted := false
      end else begin
        if self.Procs[self.IndexOfUnit(s1)].waiting_for_dependent_initialization then
          bAllStarted := false;
        if not self.Procs[self.IndexOfUnit(s1)].initialized then
          bAllStarted := false;
      end;
    end;
  end;

  if s1 <> '' then begin
    if not self.HasUnit(s1) then
      bAllStarted := false
    else begin
      if self.Procs[self.IndexOfUnit(s1)].waiting_for_dependent_initialization then
        bAllStarted := false;
      if not self.Procs[self.IndexOfUnit(s1)].initialized then
        bAllStarted := false;
    end;

    if lowercase(s1) <> lowercase(result.name) then begin
      result.dependencies := result.dependencies + '['+lowercase(s1)+']';
      if result.cs_dependencies = '' then
        result.cs_dependencies := lowercase(s1)
      else
        result.cs_dependencies := result.cs_dependencies + ','+lowercase(s1);
    end;
  end;

  //if not all dependencies have been started, defer this initialization for later
  result.waiting_for_dependent_initialization := not bAllStarted;

  //if all dependencies have been started then we can just go ahead and init now
  if bAllStarted then begin
{$IFNDEF OI_NOCHECK}
    if not IsDLL then
      result.DoInit;
{$ENDIF}
    self.FmetRequirements.Add(lowercase(result.name));
  end else begin
    RememberRequiredUnits(result.dependencies);
{$IFNDEF OI_NOCHECK}
  {$IFDEF LOG_UNIT_INIT}
    Debug.Log(extractfilename(DLLName)+': Deferring initialization of '+result.name+' which has dependencies: '+result.dependencies);
  {$ENDIF}
{$ENDIF}

  end;

  //if this unit was depended on by any other units then, initialize those units.
{$IFNDEF OI_NOCHECK}
  if not IsDLL then begin
    CheckAllMet;
{$IFDEF LOG_UNIT_INIT}
    Debug.Log(extractfilename(DLLName)+': Tried initialization of '+result.name+' which has dependencies: '+result.dependencies);
{$ENDIF}

  end;
{$ENDif}


end;

{ TPair }

function TPair.AllDependenciesAvailable: boolean;
var
  s1, s2: string;
  i: ni;
begin
  result := true;
  s2 := cs_dependencies;
  s1 := '';
  while SplitString(s2, ',', s1,s2) do begin
    i := ord.IndexOfUnit(s1);
    if (i<0) then
      exit(false);
  end;

  if s1 <> '' then begin
    i := ord.IndexOfUnit(s1);
    if (i<0) then
      exit(false);
  end;
end;


function TPair.DependenciesMet: boolean;
var
  s1, s2: string;
  i: ni;
begin
  result := true;
  s2 := cs_dependencies;
  s1 := '';
  while SplitString(s2, ',', s1,s2) do begin
    i := ord.IndexOfUnit(s1);
    if (i<0) then
      exit(false);
    if not ord.Procs[i].initialized then
      exit(false);

  end;

  if s1 <> '' then begin
    i := ord.IndexOfUnit(s1);
    if (i<0) then
      exit(false);
    if not ord.Procs[i].initialized then
      exit(false);
  end;

end;

procedure TPair.DoInit;
begin
  if initialized then begin
    ConsoleDebug(extractfilename(DLLName)+': Already Initialized !!!!!!!!!!!!!!!!! '+name);
    exit;
  end;

{$IFDEF LOG_UNIT_INIT}
  ConsoleDebug(extractfilename(DLLName)+': Initialize '+name);
{$ENDIF}

  if assigned(init) then
    init();
{$IFDEF ALLOW_ANON_INIT}
  if assigned(anoninit) then
    anoninit();
{$ENDIF}
{$IFDEF LOG_UNIT_INIT}
  ConsoleDebug(extractfilename(DLLName)+': Finished Initialize '+name);
{$ENDIF}

  initialized := true;
  waiting_for_dependent_initialization := false;

  initorder := ord.initcounter;
  inc(ord.initcounter);

  if self.WasDependedOn then
    self.StartDependents;



end;

function TPair.HasDependency(sName: string): boolean;
begin
  result := pos('['+lowercase(sNAme)+']',lowercase(dependencies)) >= strzero;

end;

procedure TPair.StartDependents;
var
  t: integer;
  p: ppair;
  slDep: TStringList;
  s: string;
begin

  for t:= 0 to ord.count-1 do begin
    p := ord.procs[t];
    if p.HasDependency(self.name) then begin
      if p.DependenciesMet then begin
        if not p.Initialized then
          p.DoInit;
      end;
    end;
  end;

  sldep := TStringlist.Create;
  try

    s := StringReplace(self.dependencies, '][', ',', [rfReplaceAll]);
    s := StringReplace(s, ']', '', [rfReplaceAll]);
    s := StringReplace(s, '[', '', [rfReplaceAll]);

    ParseString(s, ',', slDep);

    for t:= 0 to slDep.Count-1 do begin
      if not ord.HasUnit(slDep[t]) then begin
        raise ECritical.Create('Missing Dependency "'+slDep[t]+'" for unit '+self.name);
      end;
    end;
  finally
    slDep.free;
  end;
end;

function TPair.WasDependedOn: boolean;
var
  t: integer;
  p: ppair;

begin
  result := false;
  for t:= 0 to ord.count-1 do begin
    p := ord.procs[t];
    if p.HasDependency(self.name) then
      result := true;
  end;
end;

procedure ConsoleDebug(s: string);
begin
  Debug.Log(nil, s);
  Debug.ConsoleLog(s);
end;

procedure InitShutdown;
begin
  ginit.free;
  ginit := nil;
end;
initialization
//  ginit := nil;

finalization
//  ConsoleDebug(system.InitContext.pvUnitTable);
  InitShutdown;

{$MESSAGE '*******************DONE COMPILING OrderlyInit.pas'}
end.


