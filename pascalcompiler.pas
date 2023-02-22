unit pascalcompiler;
// This unit contains classes for parsing object pascal source code. See individual units for details.
{$DEFINE MATURE_RECORD}
{x$DEFINE ALLOW_FIREHOSE}
interface

uses debug,
{$IFDEF ALLOW_FIREHOSE}consoleglobal,{$ENDIF}
  contnrs, namevaluepair, sysutils, classes, diagram, stringx,multibuffermemoryfilestream,
  sharedobject, stringx.ansi, generics.collections, betterobject, typex, helpers_stream;

type
  EDocCompile = class(Exception);
  TStackChangedEvent = procedure of object;
  TStackPushEvent = procedure of object;
  TStackPopEvent = procedure of object;

  TCompiler = class; // forward
  // ----------------------------------------------------------------------------
  TCompilerClass = class of TCompiler;

  // Enumerated Types
  TParseContext =
  // this type describes the current context the compiler is working in.
    (pcNone = 0,
    { 01 } pcProgram,
    // the compiler is in the root of a unit that begins in "program"
    { 02 } pcProgramBody,
    // the compiler is in the body of a unit that begins with "program"
    { 03 } pcUnit,
    // the compiler used in the body of a unit that begins with "unit"
    { 04 } pcUnitName, // the compiler is defining the unit name
    { 05 } pcUses, // the compiler is analyzing unit dependencies
    { 06 } pcVar, // the compiler is in a var section
    { 07 } pcConst, // compiler using a constant declaration
    { 08 } pcType, // the compiler is in a type declaration
    { 09 } pcTypeDefinition, // the compiler is in a type definition
    { 10 } pcInterface, // the compiler using the interface action of a unit
    { 11 } pcImplementation,
    // compiler is in the implementation section of a unit
    { 12 } pcLibrary,
    // be compiler is in the root of a unit that begins with "library"
    { 13 } pcFunctionDeclaration,
    // be compiler used in the declaration of a function
    { 14 } pcFunctionDeclarationName,
    // be compiler used in the declaration of a function
    { 15 } pcFunctionName, // the compiler is parsing the name of a function
    { 16 } pcFunctionParam,
    // the compiler is parsing a parameter of the function
    { 17 } pcFunctionResult,
    // the compiler is parsing the result type of a function
    { 18 } pcFunctionBody, // the compiler is parsing the body of a function
    { 19 } pcInitialization,
    // the compiler is in the initialization section of the unit
    { 20 } pcClassDefinition, // the compiler is in a class definition
    { 21 } pcClassDefinitionHeader,
    // the compiler is in a class that definition but has not reached the body
    { 22 } pcRecordDefinition, // compiler is in a record definition
    { 23 } pcFinalization,
    // the compiler is in the finalization section of the unit
    { 24 } pcComment, // the compiler is in a standard comment
    { 25 } pcLineComment, // the compiler is a end-of-line line comment
    { 26 } pcCodeComment, // the compiler is in a comment that begins with (*
    { 27 } pcString, // the compiler is parsing a string
    { 28 } pcParens, // the compiler is parsing someting in parens
    { 29 } pcPropertyDeclaration,
    { 30 } pcPropertyDeclarationName,
    { 31 } pcPropertyDeclarationIndex,
    { 32 } pcPropertyDeclarationResult,
    { 33 } pcPropertyDeclarationWrite,
    { 34 } pcPropertyDeclarationRead,
    { 35 } pcBrackets,
    { 36 } pcFunction,
    { 37 } pcProcedure,
    { 38 } pcFunctionImpName,
    { 39 } pcDirective, // not implemented for pascal
    { 30 } pcMacro, // not implemented for pascal
    { 41 } pcDefine, // not implemented for pascal
    { 42 } pcPreIF, // not implemented for pascal
    { 43 } pcPreIFDEF, // not implemented for pascal
    { 44 } pcStruct, // not implemented for pascal
    { 45 } pcStructDoc, // not implemented for pascal
    { 46 } pcEnum, // not implemented for pascal
    { 47 } pcStorageSymbol, // not implemented for pascal
    { 48 } pcCodeBlock,
    { 49 } pcStructName,
    { 50 } pcUnitDocumentation, // not implemented for pascal
    { 51 } pcDecorations,
    // not implemeneted for pascal, represents the context in which the system tries to determine if it is a variable, function being declared
    { 52 } pcAncestorList,
    { 53 } pcTypeTypeParameters,
    { 54 } pcAncestorTypeParameters,
    { 55 } pcFunctionTypeParameters,
    { 56 } pcClassOrMetaOrForward,
    { 57 } pcMetaClassOf,
    { 58 } pcEmbeddedType
           );

  TContext = class(TBetterObject)
  public
    ParseContext: TParseContext;
    NameSpaceName: string;
    Symbol: TSymbol;
    Parent: TContext;
    function GetFullyQualifiedNameSpaceName: string;
    function GetParentContext: string;
  end;

  TDebugContextSwitch = procedure (s: string; color: integer) of object;

  // ----------------------------------------------------------------------------
  TContextStack = class(TObject)
    // maintains a hierarchy of contexts that the compiler has parsed
    // use Push() to push a context on the stack
    // use Pop() to remove a context from the stack
    // used to get current context read the current context
  private
    Fcontexts: TList<TContext>;
    FonStackChange: TStackChangedEvent;
    FPreviousContext: TParseContext;
    FonStackPop: TStackPopEvent;
    FonStackPush: TStackPushEvent;
    procDebugContextSwitch: TDebugContextSwitch;
    function GetCurrentcontext: TParseContext;
    procedure SetCurrentContext(const Value: TParseContext);
    function GetParentcontext: TParseContext;
    function GetPreviousContext: TParseContext;
    function GetCurrentSymbolContext: TSymbol;
    procedure SetCurrentSymbolContext(const Value: TSymbol);
    function GetCurrentcontextObject: TContext;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;
    function FindContextByType(ParseContextType: TParseContext): TContext;
    procedure Push(context: TParseContext; symbolcontext: TSymbol = nil);
    function Pop: TParseContext;
    procedure DebugContextSwitch(s: string; color: integer);
    procedure Clear;
    property CurrentParseContext: TParseContext read GetCurrentcontext
      write SetCurrentContext;
    property CurrentContext: TContext read GetCurrentcontextObject;

    property CurrentSymbolContext: TSymbol read GetCurrentSymbolContext
      write SetCurrentSymbolContext;
    property Current: TParseContext read GetCurrentcontext
      write SetCurrentContext;
    property Parent: TParseContext read GetParentcontext;
    property OnStackChange: TStackChangedEvent read FonStackChange
      write FonStackChange;
    property OnStackPop: TStackPopEvent read FonStackPop write FonStackPop;
    property OnStackPush: TStackPushEvent read FonStackPush write FonStackPush;

    property PreviousContext: TParseContext read GetPreviousContext;
    procedure Changed;
    procedure Pushed;
    procedure Popped;
    function IsWithin(c: TParseContext): boolean;
  end;

  // ----------------------------------------------------------------------------
  TCompiler = class(TLockQueuedObject)
    // the compiler class is a generic compiler
    // it does not have any specific parsing abilities or any specific language
    // inherit a new class from Tcompiler to implement compilation for a specific language
    // its primary properties include:
    // an input property for inputting the source to be compiled
    // an output property for generating results
    // a compilation loop that can be overridden to trigger defense in sub-classes
  private
    FOnProgress: TCompilerProgressEvent;
    FFileName: string;
    FpreviousPosition: integer;
    function GetAdvanceWasBlocked: boolean;
  protected
    debugstream: TMultiBufferMemoryFileStream;
    column: nativeint;
    linenumber: nativeint;
    position: nativeint;
    FStack: TContextStack;
    FBlockAdvance: boolean;

    FLastCommittedFunction: TFunctionDefinition;
    FLastCommittedProperty: TPropertyDefinition;
    FcurrentFunction: string;
    FBuffer: string;
    FInput: string;
    FOutput: string;
    FOnDebug: TNotifyEvent;
    FOnContextChange: TNotifyEvent;
    FProject: TUMLProject;
    debugcolor: integer;
    FSymbolStack: TList<TSymbol>;
    procedure SetInput(sValue: string);
    function GetInput: string;
    function GetOutput: string;
    procedure Comment;
    function GetCurChar: Char;
    function PrevWordIs(s: string): boolean;
    function AtWord(sWord: string; bCaseSensitive: boolean = false)
      : boolean;
    function GetCurrentWord: string;
    function CurrentWordIs(word: string): boolean;
    function GetPreviousWord: string;

    procedure DispatchContext; virtual; abstract;

    procedure Write(sString: string);
    procedure BufferWrite(sString: string);
    procedure ClearBuffer;

    property CurChar: Char read GetCurChar;
    function AtWordBreak: boolean;
    function AtEndOfPattern(sPattern: string;
      bCaseSensitive: boolean = false): boolean;
    function AtEndOfWord(sWord: string;
      bCaseSensitive: boolean = false): boolean;
    function AtBeginningOfPattern(sPattern: string;
      bCaseSensitive: boolean = false): boolean;
    procedure debug;
    procedure BufferChar;
    procedure SetDebugOutput(sFile: string);
    procedure DebugWrite(s: string; clr: integer);
    procedure DebugContextSwitch(s: string; clr: integer);
  public

    constructor Create; override;
    destructor Destroy; override;
    function Compile(sFile: string): boolean; virtual;
    property Stack: TContextStack read FStack;
  published
    property Project: TUMLProject read FProject write FProject;
    property LastCommittedFunction: TFunctionDefinition
      read FLastCommittedFunction write FLastCommittedFunction;
    property LastCommittedProperty: TPropertyDefinition
      read FLastCommittedProperty write FLastCommittedProperty;
    procedure BlockAdvance;
    procedure Advance(iBy: nativeint);
    property CurrentFunction: string read FcurrentFunction
      write FcurrentFunction;
    property Buffer: string read FBuffer;
    property Input: string read GetInput write SetInput;
    property Output: string read GetOutput;
    property OnDebug: TNotifyEvent read FOnDebug write FOnDebug;
    property OnContextChange: TNotifyEvent read FOnContextChange
      write FOnContextChange;
    property CurrentWord: string read GetCurrentWord;
    property PreviousWord: string read GetPreviousWord;
    procedure OpenFont(scolor: string);
    procedure CloseFont;

    procedure HandleOnStackChange;
    procedure HandleOnStackPush;
    procedure HandleOnStackPop;
    property filename: string read FFileName write FFileName;
    property OnProgress: TCompilerProgressEvent read FOnProgress
      write FOnProgress;
    procedure DebugEvent(sMessage: string; scolor: string = '#0000FF');
    property AdvanceWasBlocked: boolean read GetAdvanceWasBlocked;
    property LastPosition: integer read FpreviousPosition
      write FpreviousPosition;
    procedure MOveThroughPattern(sPattern: string);
  end;

  // ----------------------------------------------------------------------------
  TPascalCompiler = class(TCompiler)
    // The Pascal compiler class is a compiler for the object Pascal language.
    // This class is implemented to work with the docsrv. project only
    // There is another PascalCompiler unit (somewhere) that was intended to
    // be a Pascal->C++ cross compiler.
  private
    maturetype: string;
    FCurrentSymbol: TSymbol;
    FCurrentUnit: TunitDefinition;
    FLastTypeName: string;
    FCurrentSignature: string;
    FCurrentProperty: string;
    FCurrentFunctionDef: TFunctionDefinition;
    FCurrentScope: TScope;
    FCurrentTypeTypeParameters: string;
    FCurrentAncestor: string;

    function GetCurrentClass: TMatureConstruct;
    procedure SetCurrentUnit(const Value: TunitDefinition);

    procedure DispatchRoot;
    procedure DispatchComment;
    procedure DispatchCodeComment;
    procedure DispatchLineComment;
    procedure DispatchUnit;
    procedure DispatchInterface;
    procedure DispatchImplementation;
    procedure DispatchType;
    procedure DispatchConst;
    procedure DispatchTypeDefinition;
    procedure DispatchClassDefinitionHeader;
    procedure DispatchClassDefinition;
    procedure DispatchParens;
    procedure DispatchBrackets;
    procedure DispatchFunctionTypeParams;
    procedure DispatchFunctionDeclaration;
    procedure DispatchPropertyDeclaration;
    procedure DispatchFunction;
    procedure DispatchCodeBlock;
    procedure DisPatchFunctionImpName;
    procedure DispatchVarConst;
    procedure DispatchString;
    procedure DispatchStruct;
    procedure DispatchStructName;
    procedure DispatchAncestorList;
    procedure DispatchTypeTypeParameters;
    procedure DispatchAncestorTypeParameters;
    procedure DispatchClassOrMetaOrForward;
    procedure DispatchMetaClassOf;
    procedure DispatchEmbeddedType;

    procedure DispatchRecordDefinition;
    procedure DispatchUses;

  public
    firehosedebug: boolean;
    constructor Create; override;

    procedure AssertCurrentUnitState;
    //Useful for debugging, this procedure will raise an exception
    //if the Compiler is in an invalid state, e.g. There's no unit defined at
    //the root of the context stack or something else is amiss.
    procedure DispatchContext; override;
    //[KEY] This is the main State-Machine Dispatch.  It calls other
    //dispatch functions e.g. DispatchUnit(), DispatchUses()
    //depending on the current state of the state engine.
    //Each dispatcher handles compilation states and can transition
    //into other states.

    // remote control functions
    procedure Doc(sString: string);
    //When documentation is found through the parser, aggregates the
    //documentation into the final structure.
    procedure DocNewLine;
    procedure FuncDoc(sString: string);
    procedure FuncDocNewLine;
    procedure PropDoc(sString: string);
    procedure PropDocNewLine;

    procedure CatalogueType(sName: string);
    procedure CommitType(sName: string);
    procedure CommitClass(sName: string);
    procedure CommitFunction;
    procedure CommitProperty;
    procedure RecommitFunction;
    procedure DebugInline(sMessage: string);

    property CurrentProperty: string read FCurrentProperty
      write FCurrentProperty;
    procedure FindFunction(sName: string);

    function Compile(sFile: string): boolean; override;

    property CurrentUnit: TunitDefinition read FCurrentUnit
      write SetCurrentUnit;
    property CurrentSymbol: TSymbol read FCurrentSymbol write FCurrentSymbol;
    property CurrentClass: TMatureConstruct read GetCurrentClass;
    procedure PushSymbolContext(sym: TSymbol);
    property LastTypeName: string read FLastTypeName write FLastTypeName;
    property CurrentSignature: string read FCurrentSignature
      write FCurrentSignature;
    procedure DefineUnit(sName: string);
    property CurrentScope: TScope read FCurrentScope write FCurrentScope;

  end;

  // TPascalCompiler2 = class(Tcompiler)

const
  validnames = ['0' .. '9', 'a' .. 'z', 'A' .. 'Z', '_'];
  wordbreaks = [' ', '(', ')', '*', '[', ']', '''', '"', '=', '+', '-', '/',
    '\', '<', '>', '{', '}', ';', ',', '.', #10, #13, #0, #9];
  // oprerators = ['+', '-', '=', '=='];

function ContextToString(pc: TParseContext): string;

implementation

// ------------------------------------------------------------------------------
procedure TCompiler.SetDebugOutput(sFile: string);
begin
  debugcolor := -1;
  if assigned(debugstream) then begin
    debugstream.free;
    debugstream := nil;
  end;

  if sFile = '' then
    exit;

  debugstream := TMultiBufferMemoryFileStream.Create(sFile, fmCreate);

end;

procedure TCompiler.SetInput(sValue: string);
begin
  FInput := sValue;
  FBlockAdvance := false;
  FBuffer := '';
  FOutput := '';
  position := 0;

end;

// ------------------------------------------------------------------------------
function TCompiler.GetInput: string;
begin
  result := FInput;
end;

// ------------------------------------------------------------------------------
function TCompiler.GetOutput: string;
begin
  result := FOutput;

end;

// ------------------------------------------------------------------------------
function TCompiler.Compile(sFile: string): boolean;
var
  iLen: integer;
  prevcontext: TParseContext;
  sym: TSymbol;
  sPrevFunction: string;

begin
  SetDebugOutput(sFile+'.debug.txt');
  self.Stack.Clear;
  filename := sFile;
  Input := LoadStringFromFile(sFile);

  result := false;
  try
    LastPosition := 0;
    position := 1;
    iLen := length(FInput);
    // for each Character process context changes
    if iLen = 0 then
      exit;
    if iLen > 500000 then
      exit;

    repeat
      prevcontext := Stack.Current;

      DispatchContext;
      debug;

      if prevcontext <> Stack.Current then
      begin
        if Stack.Current = pcLineComment then
        begin
          if LastCommittedFunction <> nil then
            Write('<font color="#FFFF00">&lt;' + LastCommittedFunction.Name +
              '&gt;</font>');
          if LastCommittedProperty <> nil then
            Write('<font color="#FFFF00">&lt;' + LastCommittedProperty.Name +
              '&gt;</font>');

        end;

      end;

      if (sPrevFunction <> CurrentFunction) and (CurChar <> '.') and
        (CurChar in wordbreaks) then
      begin
        Write('<font color="#FF00FF">' + CurrentFunction + '</font>');
        sPrevFunction := CurrentFunction;
      end;

      if not FBlockAdvance then
      begin
        if CurChar = '<' then
        begin
          WRite('&lt;');
        end
        else if CurChar = ' ' then
        begin
          WRite('&nbsp;');
        end
        else if CurChar = '>' then
        begin
          WRite('&gt;');
        end
        else
          Write(CurChar);

        if CurChar = #10 then
        begin
          WRite('<BR>');
        end;

        Advance(1);
      end;

      LastPosition := position;
      FBlockAdvance := false;
    until position > iLen;

    result := true;

    DebugEvent('Ended in context ' + ContextToString(self.Stack.Current));

  except
    On E: Exception do
    begin
      result := false;
      write('*BOMB*' + E.Message);
      log(self, E.Message, 'error');
      // writeln('*BOMB*'+e.Message);
      // raise Exception.create(e.message);
    end;
  end;

end;

// ------------------------------------------------------------------------------
constructor TCompiler.Create;
begin
  inherited;
  FSymbolStack := TList<TSymbol>.create;
  FBlockAdvance := false;
  FOnDebug := nil;
  FBuffer := '';
  FOutput := '';
  FInput := '';
  FStack := TContextStack.Create;
  FStack.procDebugContextSwitch := self.DebugContextSwitch;
  FStack.OnStackChange := self.HandleOnStackChange;
  FStack.OnStackPush := self.HandleOnStackPush;
  FStack.OnStackPop := self.HandleOnStackPop;

end;

function TCompiler.CurrentWordIs(word: string): boolean;
begin
  result := comparetext(currentword,word)=0;
end;

{ TTagInfo }

{ TContextStack }

// ------------------------------------------------------------------------------
procedure TContextStack.Changed;
begin
  if assigned(OnStackChange) then
    OnStackChange;
end;

procedure TContextStack.Clear;
begin
  Fcontexts.Clear;
  Push(pcNone);
end;

constructor TContextStack.Create;
begin
  Fcontexts := TList<TContext>.Create;
  Push(pcNone);
end;

// ------------------------------------------------------------------------------
procedure TContextStack.DebugContextSwitch(s: string;color: integer);
begin
  if assigned(procDebugContextSwitch) then
    procDebugContextSwitch(s,color);

end;


destructor TContextStack.Destroy;
begin
  Fcontexts.free;
  inherited;
end;

function TContextStack.FindContextByType(
  ParseContextType: TParseContext): TContext;
begin
  result := CurrentContext;
  while result <> nil do begin
    if result.ParseContext = ParseContextType then
      exit(result);
    result := result.parent;
  end;
end;

// ------------------------------------------------------------------------------
function TContextStack.GetCurrentcontext: TParseContext;
begin
  result := Fcontexts[Fcontexts.count - 1].ParseContext;
end;

function TContextStack.GetCurrentcontextObject: TContext;
begin
  result := FContexts[FContexts.count-1];
end;

function TContextStack.GetCurrentSymbolContext: TSymbol;
var
  t: integer;
begin
  result := nil;
  for t := FContexts.count - 1 downto 0 do
  begin
    result := FContexts[t].Symbol;
    if result <> nil then
      break;
  end;

end;

// ------------------------------------------------------------------------------
function TContextStack.GetParentcontext: TParseContext;
begin
  if Fcontexts.count > 1 then
    result := Fcontexts[Fcontexts.count - 2].ParseContext
  else
    result := pcNone;;

end;

function TContextStack.GetPreviousContext: TParseContext;
begin
  result := FPreviousContext;
end;

function TContextStack.IsWithin(c: TParseContext): boolean;
var
  t: integer;
  cc: TParseContext;
begin
  result := false;
  for t := 0 to Fcontexts.count - 1 do
  begin
    cc := self.Fcontexts[t].ParseContext;
    if c = cc then
    begin
      result := true;
      break;
    end;
  end;
end;

function TContextStack.Pop: TParseContext;
var
  c: Tcontext;
begin
  var poppedcontext := GetcurrentContext;
  FPreviousContext := GetCurrentcontext;
  c := FContexts[FContexts.count-1];
  Fcontexts.Delete(Fcontexts.count - 1);
  c.free;
  c := nil;
  result := GetCurrentcontext;
  Popped;
  DebugContextSwitch('■'+ContextToString(poppedcontext)+'->'+ContextToString(result)+'▪',9);
end;

procedure TContextStack.Popped;
begin
  if assigned(OnStackPop) then
    OnStackPop;

end;

// ------------------------------------------------------------------------------
procedure TContextStack.Push(context: TParseContext;
  symbolcontext: TSymbol = nil);
var
  c: TContext;
begin
  c := TContext.create;
  c.parsecontext := context;
  c.Symbol := symbolcontext;
  if FContexts.count > 0 then
    c.parent := FContexts[FContexts.count-1]
  else
    c.parent := nil;

  FPreviousContext := context;
  Fcontexts.Add(c);
  DebugContextSwitch(ContextToString(context),15);
  Pushed;
end;

procedure TContextStack.Pushed;
begin
  if assigned(OnStackPush) then
    OnStackPush;

end;

// ------------------------------------------------------------------------------
destructor TCompiler.Destroy;
begin
  FStack.free;
  FSymbolStack.free;
  SetDebugOutput('');
  inherited;
end;

// ------------------------------------------------------------------------------
procedure TCompiler.Comment;
begin

  // TODO -cunimplemented: unimplemented block
end;

// ------------------------------------------------------------------------------
procedure TCompiler.Write(sString: string);
begin
  FOutput := FOutput + sString;
end;

// ------------------------------------------------------------------------------
function TCompiler.AtEndOfPattern(sPattern: string;
  bCaseSensitive: boolean): boolean;
var
  sScope: string;
begin
  sScope := copy(FInput, position - length(sPattern), length(sPattern));

  if bCaseSensitive then
  begin
    sScope := lowercase(sScope);
    sPattern := lowercase(sPattern);
  end;

  result := sScope = sPattern;

end;

// ------------------------------------------------------------------------------
function TCompiler.GetAdvanceWasBlocked: boolean;
begin
  result := LastPosition = position;
end;

function TCompiler.GetCurChar: Char;
begin
  if position > high(Finput) then
    exit(#0);
  result := FInput[position];
end;

// ------------------------------------------------------------------------------
procedure TCompiler.BufferWrite(sString: string);
begin
  FBuffer := FBuffer + sString;
end;

// ------------------------------------------------------------------------------
function TCompiler.AtBeginningOfPattern(sPattern: string;
  bCaseSensitive: boolean): boolean;
var
  sScope: string;
begin
  sScope := copy(FInput, position, length(sPattern));

  if bCaseSensitive then
  begin
    sScope := lowercase(sScope);
    sPattern := lowercase(sPattern);
  end;

  result := sScope = sPattern;
end;

// ------------------------------------------------------------------------------
procedure TContextStack.SetCurrentContext(const Value: TParseContext);
var
  c: TContext;
begin
  FPreviousContext := GetCurrentcontext;
  c := Fcontexts[Fcontexts.count - 1];
  c.ParseContext := value;
  Fcontexts[Fcontexts.count - 1] := c;
  Changed;
end;

// ------------------------------------------------------------------------------
procedure TContextStack.SetCurrentSymbolContext(const Value: TSymbol);
var
  c: TContext;
begin
  c := Fcontexts[Fcontexts.count - 1];
  c.Symbol := Value;
  Fcontexts[Fcontexts.count - 1] := c;
  Changed;
end;

// ------------------------------------------------------------------------------
procedure TCompiler.debug;
begin
  If assigned(OnDebug) then
    OnDebug(self);

end;


procedure TCompiler.DebugContextSwitch(s: string; clr: integer);
begin
  DebugWrite(s,clr);
end;

procedure TCompiler.DebugEvent(sMessage, scolor: string);
begin
  Write('<font color="' + scolor + '">&lt;debug msg="' + sMessage +
    '"/&gt;</font>');

end;

procedure TCompiler.DebugWrite(s: string; clr: integer);
begin
  if clr <> debugcolor then begin
    s := '`c'+inttohex(clr)+'`'+s;
    debugcolor := clr;
  end;

{$IFDEF ALLOW_FIREHOSE}
  con.AutoCRLF := false;
  con.writeex(s);
{$ENDiF}
  helpers_stream.Stream_GuaranteeWrite(debugstream, @s[low(s)], length(s)*sizeof(char));
end;

// ------------------------------------------------------------------------------
function ContextToString(pc: TParseContext): string;
begin
  case pc of
    pcNone:
      result := 'pcNone';
    pcProgram:
      result := 'pcProgram';
    pcProgramBody:
      result := 'pcProgramBody';
    pcUnit:
      result := 'pcUnit';
    pcUnitName:
      result := 'pcUnitName';
    pcUses:
      result := 'pcUses';
    pcVar:
      result := 'pcVar';
    pcConst:
      result := 'pcConst';
    pcType:
      result := 'pcType';
    pcTypeDefinition:
      result := 'pcTypeDefinition';
    pcInterface:
      result := 'pcInterface';
    pcImplementation:
      result := 'pcImplementation';
    pcFunctionImpName:
      result := 'pcFunctionImpName';
    pcCodeBlock:
      result := 'pcCodeBlock';
    pcLibrary:
      result := 'pcLibrary';
    pcFunction:
      result := 'pcFunction';
    pcProcedure:
      result := 'pcProcedure';
    pcFunctionDeclaration:
      result := 'pcFunctionDeclaration';
    pcFunctionName:
      result := 'pcFunctionName';
    pcFunctionParam:
      result := 'pcFunctionParam';
    pcFunctionResult:
      result := 'pcFunctionResult';
    pcFunctionBody:
      result := 'pcFunctionBody';
    pcFunctionDeclarationName:
      result := 'pcFunctionDeclarationName';
    pcInitialization:
      result := 'pcInitialization';
    pcClassDefinition:
      result := 'pcClassDefinition';
    pcRecordDefinition:
      result := 'pcRecordDefinition';
    pcClassDefinitionHeader:
      result := 'pcClassDefinitionHeader';
    pcFinalization:
      result := 'pcFinalization';
    pcComment:
      result := 'pcComment';
    pcLineComment:
      result := 'pcLineComment';
    pcCodeComment:
      result := 'pcCodeComment';
    pcString:
      result := 'pcString';
    pcParens:
      result := 'pcParens';
    pcPropertyDeclaration:
      result := 'pcPropertyDeclaration';
    pcPropertyDeclarationName:
      result := 'pcPropertyDeclarationName';
    pcPropertyDeclarationIndex:
      result := 'pcPropertyDeclarationIndex';
    pcPropertyDeclarationResult:
      result := 'pcPropertyDeclarationResult';
    pcPropertyDeclarationWrite:
      result := 'pcPropertyDeclarationWrite';
    pcPropertyDeclarationRead:
      result := 'pcPropertyDeclarationRead';
    pcBrackets:
      result := 'pcBrackets';
    pcDefine:
      result := 'pcDefine';
    pcDirective:
      result := 'pcDirective';
    pcStructName:
      result := 'pcStructName';
    pcStruct:
      result := 'pcStruct';
    pcStructDoc:
      result := 'pcStructDoc';
    pcDecorations:
      result := 'pcDecorations';
    pcStorageSymbol:
      result := 'pcStorageSymbol';
    pcUnitDocumentation:
      result := 'pcUnitDocumentation';
    pcAncestorList:
      result := 'pcAncestorList';
    pcTypeTypeParameters:
      result := 'pcTypeTypeParameters';
    pcAncestorTypeParameters:
      result := 'pcAncestorTypeParameters';
    pcFunctionTypeParameters:
      result := 'pcFunctionTypeParameters';
    pcClassOrMetaOrForward:
      result := 'pcClassOrMetaOrForward';
    pcMetaClassOf:
      result := 'pcMetaClassOf';
    pcEmbeddedType:
      result := 'pcEmbeddedType';

  else
    result := 'unknown ' + inttostr(ord(pc));
  end;
end;

// ------------------------------------------------------------------------------
procedure Register;
begin
  // RegisterComponents('Booger', [TPascalCompiler]);
end;

// ------------------------------------------------------------------------------
constructor TPascalCompiler.Create;
begin
  inherited;
  FsymbolStack := TList<TSymbol>.create;
  firehosedebug := true;
  FProject := nil;
  FCurrentUnit := nil;
  FCurrentSymbol := nil;
  FcurrentFunction := '';
  FCurrentUnit := nil;
  FCurrentSignature := '';
  self.FLastCommittedFunction := nil;
  self.FLastCommittedProperty := nil;

end;

// ------------------------------------------------------------------------------
procedure TCompiler.BufferChar;
begin
  BufferWrite(CurChar);
end;

procedure TPascalCompiler.CommitClass(sName: string);
var
  sym: TClassDefinition;
begin
  if sName = '' then
    exit;

  DebugInline('TYPE COMMITED:' + sName);

  if lowercase(sName) = lowercase(self.CurrentUnit.ClassName) then
    raise Exception.Create('Class Name cannot match unit name: ' + sName);

  sym := TClassDefinition.Create(Trim(sName), Project, self.CurrentUnit);
  sym.MatureType := maturetype;
  sym.fil := extractfilename(filename);
  sym.col := 0;
  sym.row := 0;
  sym.position := self.position;

  sym.TypeParameters := FCurrentTypeTypeParameters;

  Project.Symbols.Add(sym);

  ClearBuffer;
  self.LastTypeName := '';
  self.CurrentSymbol := sym;
  Fsymbolstack.add(sym);

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.AssertCurrentUnitState;
begin
  if (not (stack.Current in [pcNone, pcUnitName, pcComment, pcCodeComment, pcLineComment])) and (CurrentUnit = nil) then
    raise Exception.Create('unit can only by nil in pcNone, pcUnitName, pcCodeComment, pcComment, and pcLineComment states');

  if (not (stack.Current in [pcNone, pcUnitName, pcComment, pcCodeComment, pcLineComment])) and (CurrentUnit.Name ='') then
    raise Exception.Create('unit is trashed');

end;

procedure TPascalCompiler.CatalogueType(sName: string);
var
  sym: TSymbol;
  s: string;
begin
  if sName = '' then
    exit;

  s := sName;//stack.currentcontext.GetFullyQualifiedNameSpaceName;
  if s <> '' then
    sName := s+'.'+sName;

  if sName <> self.LastTypeName then
  begin
    write('<font color="#00007F">&lt;***TYPE Catalogued:' + sName +
      '***&gt;</font>');
    self.LastTypeName := sName;
  end;
  ClearBuffer;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.CommitType(sName: string);
var
  sym: TClassDefinition;
begin
  if sName = '' then
    exit;

  var slh := ParseStringh(sName,'.');
  sName := slh.o[slh.o.Count-1];

  if zpos('TBetterList', sName)>=0 then
    log('trap');

  if currentunit.Name = '' then begin
    raise Exception.create('cannot commit type '+sName+' because current unit name is blank (for some reason)');

  end;


  write('&lt;***TYPE COMMITED:' + sName + '***&gt;');


  if not assigned(FCurrentUnit) then
    raise Exception.Create('No Current Unit defined, parsing: ' + sName);

  if (lowercase(sName) = lowercase(self.FCurrentUnit.Name)) then
    raise Exception.Create('Type Name cannot match unit name: ' + sName);

  if not CurrentUnit.isgood then
    raise Exception.Create('Wild pointer detected');


  sym := TClassDefinition.Create(Trim(sName), Project, self.CurrentUnit);
  sym.MatureType := maturetype;
  sym.fil := extractfilename(filename);
  sym.col := 0;
  sym.row := 0;
  sym.position := self.position;
  FCurrentAncestor := '';

  Project.Symbols.Add(sym);

  ClearBuffer;
  self.LastTypeName := '';
  sym.TypeParameters := FCurrentTypeTypeParameters;
  self.CurrentSymbol := sym;
  Fsymbolstack.add(sym);

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DebugInline(sMessage: string);
begin
  log(sMessage);
  write('&lt;***' + sMessage + '***&gt;');
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DefineUnit(sName: string);
var
  sym: TunitDefinition;
begin

  if self.Project.Symbols.HasSymbol(sName) then
    raise EDocCompile.Create('Unit name ' + sName +
      ' already exists in project');

  sym := TunitDefinition.Create(sName, Project, nil);
  sym.fil := extractfilename(filename);

  stack.currentcontext.namespacename := sName;
  sym.FullyQualifiedName := sName;


  CurrentUnit := sym;

  self.Project.Symbols.Add(sym);

  ClearBuffer;

  self.CurrentSymbol := sym;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchClassDefinition;
begin
  if CurChar = '(' then
    Stack.Push(pcParens);

  if AtEndOfWord('type') then begin
    Stack.Push(pcEmbeddedType);
    DebugWrite ('**entering pcEmbeddedType with '+FSymbolStack.Count.ToString+' on the stack***',13);
  end;

  if AtEndOfWord('public') then
  begin
    self.CurrentScope := scPublic;
  end;



  if AtEndOfWord('published') then
  begin
    self.CurrentScope := scPublished;
  end;

  if AtEndOfWord('private') then
  begin
    self.CurrentScope := scPrivate;
  end;

  if AtEndOfWord('protected') then
  begin
    self.CurrentScope := scProtected;
  end;

  if AtEndOfWord('procedure') or AtEndOfWord('function') then
  begin
    // if currentSignature <> '' then
    // commitfunction;
    CurrentSignature := PreviousWord + ' ';
    CurrentFunction := '';
    Stack.Push(pcFunctionDeclaration);
    Stack.Push(pcFunctionDeclarationName);
  end;

  if AtEndOfWord('property') then
  begin
    // if currentSignature <> '' then
    // commitfunction;
    CurrentSignature := PreviousWord + ' ';
    CurrentFunction := '';
    CurrentProperty := '';
    LastCommittedFunction := nil;
    Stack.Push(pcPropertyDeclarationName);
  end;

  // these things can appear that affect the last committed function
  if AtWord('overload') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffOverload];

  if AtWord('override') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffoverride];

  if AtWord('reintroduce') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffreintroduce];

  if AtWord('virtual') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffvirtual];

  if AtWord('dynamic') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffdynamic];

  if AtWord('stdcall') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffstdcall];

  if AtWord('register') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffregister];

  if AtWord('abstract') then
    if assigned(LastCommittedFunction) then
      self.LastCommittedFunction.Flags := self.LastCommittedFunction.Flags +
        [ffabstract];

  if AtEndOfWord('end') then
    Stack.Pop;
end;

procedure TPascalCompiler.DispatchRecordDefinition;
begin
{$IFDEF MATURE_RECORD}
  DispatchClassDefinition;
{$ELSE}
  if AtEndOfWord('end') then
    Stack.Pop;
{$ENDIF}

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchCodeComment;
begin
  if AtEndOfPattern('*)') then
  begin
    Stack.Pop;
    BlockAdvance;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchComment;
begin
  if AtEndOfPattern('}') then
  begin
    Stack.Pop;
    BlockAdvance;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchContext;
begin

   // GLOG.Debug('ln:'+inttostr(linenumber)+' col:'+inttostr(column)+' Ctx: '+ContextToString(stack.Current));
  // if anything but string, determine comment states
  if not(Stack.Current in [pcString, pcComment, pcLineComment, pcCodeComment])
  then
  begin
    if AtEndOfPattern('{') then
      Stack.Push(pcComment);

    if AtEndOfPattern('//') then
      Stack.Push(pcLineComment);

    if AtEndOfPattern('(*') then
      Stack.Push(pcCodeComment);
  end;

  if not(Stack.Current in [pcString, pcComment, pcLineComment, pcCodeComment])
  then
  begin
    if AtEndOfPattern('''') then
    begin
      Stack.Push(pcString);
      exit;
    end;
  end;

  AssertCurrentUnitState;

  // dispatch contexts
  case Stack.Current of
    pcNone:
      DispatchRoot;
    pcComment:
      DispatchComment;
    pcLineComment:
      DispatchLineComment;
    pcCodeComment:
      DispatchCodeComment;
    pcUnit, pcUnitName, pcLibrary, pcProgram:
      DispatchUnit;
    pcInterface:
      DispatchInterface;
    pcImplementation:
      DispatchImplementation;
    pcType:
      DispatchType;
    pcConst:
      DispatchConst;
    pcTypeDefinition:
      DispatchTypeDefinition;
    pcUses:
      DispatchUses;
    pcClassDefinition:
      DispatchClassDefinition;
    pcRecordDefinition:
      DispatchRecordDefinition;
    pcClassDefinitionHeader:
      DispatchClassDefinitionHeader;
    pcParens:
      DispatchParens;
    pcFunction, pcProcedure:
      DispatchFunction;
    pcFunctionDeclaration, pcFunctionResult, pcFunctionDeclarationName:
      DispatchFunctionDeclaration;
    pcPropertyDeclaration, pcPropertyDeclarationName,
      pcPropertyDeclarationIndex, pcPropertyDeclarationResult,
      pcPropertyDeclarationWrite, pcPropertyDeclarationRead:
      DispatchPropertyDeclaration;
    pcBrackets:
      DispatchBrackets;
    pcCodeBlock:
      DispatchCodeBlock;
    pcFunctionImpName:
      DisPatchFunctionImpName;
    pcVar:
      DispatchVarConst;
    pcString:
      DispatchString;
    pcStruct:
      DispatchStruct;
    pcAncestorList:
      DispatchAncestorList;
    pcTypeTypeParameters:
      DispatchTypeTypeParameters;
    pcAncestorTypeParameters:
      DispatchAncestorTypeParameters;
    pcFunctionTypeParameters:
      DispatchFunctionTypeParams;
    pcClassOrMetaOrForward:
      DispatchClassOrMetaOrForward;
    pcMetaClassOf:
      DispatchMetaClassOf;
    pcEmbeddedType:
      DispatchEmbeddedType;
  else
    raise Exception.Create('Context not handled');
  end;
  if firehosedebug then begin
    DebugWrite(self.CurChar,10);
  end;
end;

procedure TPascalCompiler.DispatchEmbeddedType;
begin
  if AtWord('procedure') or AtWord('function') or AtWord('constructor') or
    AtWord('destructor') or AtWord('initialization') or AtWord('finalization')
    or AtWord('public')
    or AtWord('private')
    or AtWord('protected')
    or AtWord('const') or AtWord('var') then
  begin
    CurrentSignature := '';
    ClearBuffer;
    Stack.Pop;
    BlockAdvance;
    if FSymbolStack.count = 0 then
      raise Exception.Create('error, context stack should have something in it, but it doesn''t');



    exit;
  end;

  if CurChar in validnames then
    BufferWrite(CurChar);

  if CurChar in wordbreaks then
  begin
    CatalogueType(Buffer);
  end;

  if CurChar = '<' then
  begin
    Stack.Push(pcTypeTypeParameters);
    FCurrentTypeTypeParameters := '<';
  end
  else if CurChar = '=' then
  begin
    Stack.Push(pcTypeDefinition);
  end;
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchFunctionTypeParams;
begin
  CurrentSignature := CurrentSignature + CurChar;

  if CurChar = '>' then
    Stack.Pop;
end;

procedure TPascalCompiler.DispatchImplementation;
begin
  self.CurrentScope := scImplementation;

  if AtWord('end') then
    Stack.Pop;

  if AtEndOfWord('procedure') or AtEndOfWord('function') or
    AtEndOfWord('constructor') or AtEndOfWord('destructor') then
  begin
    Stack.Push(pcFunction);
    CurrentSignature := PreviousWord + ' ';
    CurrentFunction := '';
    self.BlockAdvance;
  end;

  if AtWord('var') then
    Stack.Push(pcVar);

  if AtWord('const') then
    Stack.Push(pcConst);

  if AtWord('uses') then
    Stack.Push(pcUses);

  if AtWord('type') then
    Stack.Push(pcType);

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchInterface;
begin
  self.CurrentScope := scInterface;

  // expect type, const, uses, var
  if AtEndOfWord('type', false) then
    Stack.Push(pcType);

  if AtEndOfWord('uses', false) then
    Stack.Push(pcUses);

  if AtEndOfWord('const', false) then
    Stack.Push(pcConst);

  if AtEndOfWord('var', false) then
    Stack.Push(pcVar);

  if AtWord('implementation') then
    Stack.Pop;

  if AtEndOfWord('implementation') then
    Stack.Pop;

  if AtEndOfWord('function') or AtEndOfWord('procedure') then
  begin
    Stack.Push(pcFunctionDeclaration);
    Stack.Push(pcFunctionDeclarationName);
    CurrentSignature := PreviousWord + ' ';
    CurrentFunction := '';
    CurrentSymbol := CurrentUnit;
  end;

  if AtEndOfWord('implementation') then
    Stack.Push(pcImplementation);

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchLineComment;
begin
  if Stack.Parent in [pcClassDefinitionHeader, pcUnit] then
  begin

    self.Doc(self.CurChar);

    if CurChar in [#13, #10] then
    begin
      self.DocNewLine;
    end;
  end
  else if Stack.Parent in [pcClassDefinition, pcFunction, pcProcedure] then
  begin
    if self.LastCommittedFunction <> nil then
    begin
      self.FuncDoc(self.CurChar);

      if CurChar in [#13, #10] then
      begin
        self.FuncDocNewLine;
      end;
    end
    else if self.LastCommittedProperty <> nil then
    begin
      self.PropDoc(self.CurChar);

      if CurChar in [#13, #10] then
      begin
        self.PropDocNewLine;
      end;
    end;
  end;

  if CurChar in [#13, #10] then
  begin
    Stack.Pop;
    // BlockAdvance;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchRoot;
begin
  // look for either "project" or "unit" or "library"
  if AtEndOfWord('unit', false) then
  begin
    Stack.Push(pcUnit);
    Stack.Push(pcUnitName);
  end;

  if AtEndOfWord('project', false) then
  begin
    Stack.Push(pcProgram);
    Stack.Push(pcUnitName);
  end;

  if AtEndOfWord('library', false) then
  begin
    Stack.Push(pcProgram);
    Stack.Push(pcUnitName);
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchType;
begin

  if AtWord('procedure') or AtWord('function') or AtWord('constructor') or
    AtWord('destructor') or AtWord('initialization') or AtWord('finalization')
    or AtWord('implementation') or AtWord('uses') or AtWord('const') or
    AtWord('var') then
  begin
    CurrentSignature := '';
    ClearBuffer;
    Stack.Pop;
    BlockAdvance;
    exit;
  end;

  if CurChar in validnames then
    BufferWrite(CurChar);

  if CurChar in wordbreaks then
  begin
    CatalogueType(Buffer);
  end;

  if CurChar = '<' then
  begin
    Stack.Push(pcTypeTypeParameters);
    FCurrentTypeTypeParameters := '<';
  end
  else if CurChar = '=' then
  begin
    Stack.Push(pcTypeDefinition);
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchTypeDefinition;

begin
  if AtEndOfWord('class') then
  begin
    maturetype := 'class';
    Stack.Pop;
    Stack.Push(pcClassOrMetaOrForward);
    BlockAdvance;
  end else
  if AtEndOfWord('interface') then
  begin
    maturetype := 'interface';
    Stack.Pop;
    Stack.Push(pcClassOrMetaOrForward);
    BlockAdvance;
  end

  else if AtWord('record') then
  begin
    maturetype := 'record';
    Stack.Pop;
    Stack.Push(pcRecordDefinition);
    CommitType(LastTypeName);
    // CommitType(LastTypeName);
  end
  else if AtWord('object') and (not PrevWordIs('of')) then
  begin
    maturetype := 'object';
    Stack.Pop;
    Stack.Push(pcRecordDefinition);
    CommitType(LastTypeName);
    // CommitType(LastTypeName);
  end
  else if CurChar = ';' then
  begin
    Stack.Pop;
    //todo 1: declare type aliases as generalizations
    //---FSymbolStack.delete(FSymbolStack.count-1);    //no, type aliases are not mature constructs and this terminates a type alias
    // CommitType(LastTypeName);
  end
  else if CurChar = '(' then
    Stack.Push(pcParens);

end;

procedure TPascalCompiler.DispatchTypeTypeParameters;
begin
  FCurrentTypeTypeParameters := FCurrentTypeTypeParameters + CurChar;

  if CurChar = '>' then
  begin
    Stack.Pop;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchUnit;
begin
  // expect uses, implementation

  // if in the unitname part of the unit then:
  if self.Stack.CurrentParseContext = pcUnitName then
  begin
    // if name Characters
    if (CurChar in validnames) then
      BufferWrite(CurChar);

    // if wordbreak Characterrs
    if CurChar in wordbreaks then
    begin
      // pop off to the previous context (program, unit, library)
      Stack.Pop;

      // define the unit from the buffered text
      DefineUnit(self.Buffer);
    end;
  end;

  if AtEndOfWord('uses') then
    Stack.Push(pcUses);

  if AtEndOfPattern('end.') then
    Stack.pop;


  if AtEndOfWord('interface') then
  begin
    self.CurrentSymbol := nil;
    Stack.Push(pcInterface);
  end;

  if AtEndOfWord('implementation') then
    Stack.Push(pcImplementation);

end;

// ------------------------------------------------------------------------------
function TCompiler.AtEndOfWord(sWord: string;
  bCaseSensitive: boolean): boolean;
var
  sScope: string;
  sPrev: string;
begin
  // prevent error at beginning of file
  // if position = 1 then begin
  // result := false;
  // exit;
  // end;

  // copy X Characters out of code to check against pattern
  // copy up to PreVIOUS Character
  sScope := copy(FInput, (position) - length(sWord), length(sWord));

  if position - length(sWord) <= 1 then
    sPrev := #0
  else
    sPrev := copy(FInput, (position - 1) - length(sWord), 1);

  if sPrev = '' then
    sPrev := #0;

  // convert if case-insensitivity required
  if NOT bCaseSensitive then
  begin
    sScope := lowercase(sScope);
    sWord := lowercase(sWord);
  end;

  // result = true if pattern match and word break found
  result := (sScope = sWord) and AtWordBreak and (sPrev[1] in wordbreaks);

end;

// ------------------------------------------------------------------------------
function TCompiler.AtWord(sWord: string; bCaseSensitive: boolean): boolean;
var
  sScope: string;
  cAfter: Char;
  sAfter: string;
begin
  // prevent error at beginning of file
  // if position = 1 then begin
  // result := false;
  // exit;
  // end;

  // copy X Characters out of code to check against pattern
  sScope := copy(FInput, position, length(sWord));

  // convert if case-insensitivity required
  if not bCaseSensitive then
  begin
    sScope := lowercase(sScope);
    sWord := lowercase(sWord);
  end;

  // result = true if pattern match and word break found
  sAfter := copy(FInput, position + length(sWord), 1);
  if sAfter <> '' then
    cAfter := sAfter[1]
  else
    cAfter := #0;

  result := (sScope = sWord) and (cAfter in wordbreaks);

  // one last check
  // if still good, check to make sure the Character before the word is a wordbreak.
  if (self.position = 1) or (self.Input[position - 1] in wordbreaks) then
    result := result
  else
    result := false;

end;

// ------------------------------------------------------------------------------
function TCompiler.AtWordBreak: boolean;
begin
  result := CurChar in wordbreaks;
end;

// ------------------------------------------------------------------------------
procedure TCompiler.ClearBuffer;
begin
  FBuffer := '';
end;

procedure TCompiler.CloseFont;
begin
  Write('</font>');
end;

// ------------------------------------------------------------------------------
function TCompiler.GetCurrentWord: string;
var
  t: integer;
  wentback: boolean;
begin
  t := position;
  wentback := false;

  //rewing until we hit a word break
  while (t > low(FInput)) and not(FInput[t] in wordbreaks) do
  begin
    dec(t);
    wentback := true;
  end;
  if wentback then
    inc(t);

  var strt := t;

  while (t < length(FInput)) and not(FInput[t] in wordbreaks) do
  begin
    inc(t);
  end;

  result := copy(FInput, strt, t - strt);

end;

// ------------------------------------------------------------------------------
procedure TCompiler.Advance(iBy: nativeint);
var
  t: nativeint;
begin

  if not FBlockAdvance then
  begin
    for t := 1 to iBy do
    begin
      inc(position);
      inc(column);
      if CurChar = #10 then
      begin
        inc(linenumber);
        column := 0;
      end;
    end;
  end;

  FBlockAdvance := false;
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchUses;
begin
  if CurChar in validnames then
    BufferWrite(CurChar);

  if CurChar = ',' then
  begin
    // project.QueueCompile(FBuffer);
    self.ClearBuffer;
  end;

  if CurChar = ';' then
  begin
    // project.QueueCompile(FBuffer);
    self.ClearBuffer;
    Stack.Pop;
  end;
end;

// ------------------------------------------------------------------------------
function TPascalCompiler.GetCurrentClass: TMatureConstruct;
begin
  result := nil;
  for var t:=FSymbolStack.Count-1 downto 0 do begin
    if FSymbolstack[t] is TMatureConstruct then
      exit(FSymbolStack[t] as TMatureConstruct);
  end;

end;

procedure TPascalCompiler.DispatchConst;
begin
  if AtWord('var') then
  begin
    Stack.Pop;
    exit;
  end;

  if AtWord('type') then
  begin
    Stack.Pop;
    exit;
  end;

  if AtWord('implementation') then
  begin
    Stack.Pop;
    exit;
  end;

  if AtWord('procedure') then
  begin
    Stack.Pop;
    exit;
  end;

  if AtWord('function') then
  begin
    Stack.Pop;
    exit;
  end;

end;

procedure TPascalCompiler.Doc(sString: string);
begin
  if self.CurrentSymbol <> nil then
  begin
    CurrentSymbol.Documentation.text := copy(CurrentSymbol.Documentation.text,
      1, length(CurrentSymbol.Documentation.text) - 2) + sString;
  end;
end;

procedure TPascalCompiler.DocNewLine;
var
  sTemp: string;
begin
  if self.CurrentSymbol <> nil then
  begin

    // if the line starts with "R:" then convert to class responsibility
    sTemp := CurrentSymbol.Documentation[CurrentSymbol.Documentation.count - 1];
    if lowercase(copy(sTemp, 1, 2)) = 'r:' then
    begin
      CurrentSymbol.responsibilities.Add(copy(sTemp, 3, length(sTemp)));
      CurrentSymbol.Documentation.Delete(CurrentSymbol.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 2)) = 'a:' then
    begin
      CurrentSymbol.Author := Trim(copy(sTemp, 3, length(sTemp)));
      CurrentSymbol.Documentation.Delete(CurrentSymbol.Documentation.count - 1);
    end
    else
    begin
      CurrentSymbol.Documentation.text :=
        CurrentSymbol.Documentation.text + #13#10;
    end;

  end;

end;

procedure TPascalCompiler.DispatchClassDefinitionHeader;
begin
  if AtWord('public') or AtWord('private') or AtWord('protected') or
    AtWord('published') then
  begin
    Stack.Pop;
    Stack.Push(pcClassDefinition);
  end;

  if CurChar in validnames then
  begin
    Stack.Pop;
    Stack.Push(pcClassDefinition);
  end;

  if CurChar = '(' then
    Stack.Push(pcAncestorList);

  // forward declaration
  IF CurChar = ';' then
    Stack.Pop;

end;

procedure TPascalCompiler.DispatchMetaClassOf;
begin
  if CurChar = ';' then begin
    stack.Pop;
    CommitType(LastTypeName);
    CurrentSymbol.MetaOf := PreviousWord;
  end;
end;

procedure TPascalCompiler.DispatchClassOrMetaOrForward;
begin
  if AtEndOfWord('of') then begin
    Stack.Pop;
//    CommitType(LastTypeName);
    Stack.Push(pcMetaClassOf);
    exit;
  end;

  if AtWord('public') or AtWord('private') or AtWord('protected') or
    AtWord('published') then
  begin
    Stack.Pop;
    Stack.Push(pcClassDefinition);
  end;

  if (CurChar in validnames) and (not CurrentWordIs('of')) then
  begin
    Stack.Pop;
    Stack.Push(pcClassDefinition);
  end else

  if CurChar = '(' then begin
    Stack.Pop;
    Stack.Push(pcClassDefinitionHeader);
    CommitType(LastTypeName);
    Stack.Push(pcAncestorList);
  end;
  if CurChar = ';' then begin
    Stack.pop;//forward declaration
  end;


end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.SetCurrentUnit(const Value: TunitDefinition);
begin
  FSymbolStack.Clear;
  if value.Name = 'DataObject' then begin
    log('turning on firehose');
    firehosedebug := true;
  end;
  Log('Current Unit: '+value.Name);
  FCurrentUnit := Value;
  if FCurrentunit.Name = '' then
    raise ECritical.create('current unit does not appear to be valid');
  self.CurrentSymbol := FCurrentUnit;
  FSymbolStack.Add(FCurrentUnit);

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchParens;
begin
  if Stack.Parent in [pcFunctionDeclaration, pcFunctionDeclarationName] then
    CurrentSignature := CurrentSignature + CurChar;

  if CurChar = ')' then
    Stack.Pop;
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchFunctionDeclaration;
begin
  CurrentSignature := CurrentSignature + CurChar;

  if (Stack.Current = pcFunctionDeclarationName) and (CurChar in validnames)
  then
    self.CurrentFunction := self.CurrentFunction + CurChar;

  if CurChar = ':' then
  begin
    // CommitFunction;
    Stack.Pop;
    Stack.Push(pcFunctionResult);
  end;
  if CurChar = ';' then
  begin
    if Stack.Current = pcFunctionResult then
      Stack.Pop;

    CommitFunction;
    Stack.Pop;

    if Stack.Current = pcFunctionDeclaration then
      Stack.Pop;
  end;

  // TODO: Enhance to parse through types in parens
  if CurChar = '(' then
  begin
    if Stack.Current = pcFunctionDeclarationName then
    begin
      Stack.Pop;
      Stack.Push(pcFunctionDeclaration);
    end;
    Stack.Push(pcParens);
  end;

  if CurChar = '<' then
  begin
    Stack.Push(pcFunctionTypeParameters);
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.CommitFunction;
var
  func: TFunctionDefinition;
begin
  if CurrentFunction = '' then
    exit;

  if currentclass = nil then
    raise ECritical.Create('cannot commit function in nil class/unit context');

  DebugWrite('$commit "' + CurrentClass.Name + '.' +
    CurrentFunction + '"$',13);
  write('<font color="#007F00">$commit "' + CurrentClass.Name + '.' +
    CurrentFunction + '"$</font>');
  // frmDebug.ShowMessage(currentSignature);

  func := self.CurrentClass.AddFunction(CurrentFunction);
  func.Signature := CurrentSignature;
  func.fil := extractfilename(filename);
  func.col := 0;
  func.row := 0;
  func.position := self.position;


  self.LastCommittedFunction := func;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.RecommitFunction;
var
  i: integer;
  func: TFunctionDefinition;
begin
  i := self.CurrentClass.ItemCount;

  if i > 0 then
  begin
    func := self.CurrentClass.Functions[i - 1];
    // func.free;
    self.CurrentClass.DeleteItem(i - 1);
  end;

  CommitFunction;

end;

// ------------------------------------------------------------------------------
function TCompiler.GetPreviousWord: string;
var
  t: integer;
begin
  if position = 0 then
  begin
    result := '';
    exit;
  end;

  //movethrough all wordbreaks until we find a word
  t := position - 1;
  while (t > low(FInput)) and (FInput[t] in wordbreaks) do
  begin
    dec(t);
  end;

  var endofword := t;

  while (t > low(FInput)) and not(FInput[t] in wordbreaks) do
  begin
    dec(t);
  end;
  inc(t);

  result := copy(FInput, t, (endofword+1) - t);

end;

procedure TCompiler.HandleOnStackChange;
begin
  Write('<font color="#FF0000">&lt;/' + ContextToString(Stack.PreviousContext) +
    '&gt;</font>');
  Write('<font color="#FF0000">&lt;' + ContextToString(Stack.Current) +
    '&gt;</font>');
end;

procedure TCompiler.HandleOnStackPop;
begin
  Write('<font color="#FF0000">&lt;/' + ContextToString(Stack.PreviousContext) +
    '&gt;</font>');
  // Write('<font color="#FF0000">&lt;'+contextToString(stack.current)+'&gt;</font>');

end;

procedure TCompiler.HandleOnStackPush;
begin
  Write('<font color="#FF0000">&lt;' + ContextToString(Stack.Current) +
    '&gt;</font>');

end;

procedure TCompiler.MOveThroughPattern(sPattern: string);
begin
  write(sPattern);
  Advance(length(sPattern));

end;

procedure TCompiler.OpenFont(scolor: string);
begin
  Write('<font color="' + scolor + '">');
end;

function TCompiler.PrevWordIs(s: string): boolean;
begin
  result := comparetext(PreviousWord,s)=0;
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.FuncDoc(sString: string);
begin
  if self.CurrentSymbol <> nil then
  begin
    LastCommittedFunction.Documentation.text :=
      copy(LastCommittedFunction.Documentation.text, 1,
      length(LastCommittedFunction.Documentation.text) - 2) + sString;

  end;
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.FuncDocNewLine;
var
  sTemp: string;
  sLeft, sRight: string;
begin
  if self.LastCommittedFunction <> nil then
  begin

    // if the line starts with "R:" then convert to class responsibility
    if LastCommittedFunction.Documentation.count = 0 then
      exit;

    sTemp := LastCommittedFunction.Documentation
      [LastCommittedFunction.Documentation.count - 1];
    if lowercase(copy(sTemp, 1, 2)) = 'a:' then
    begin
      LastCommittedFunction.Author := Trim(copy(sTemp, 3, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 7)) = 'author:' then
    begin
      LastCommittedFunction.Author := Trim(copy(sTemp, 8, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 4)) = 'web:' then
    begin
      LastCommittedFunction.WebPage := Trim(copy(sTemp, 5, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 2)) = 'w:' then
    begin
      LastCommittedFunction.WebPage := Trim(copy(sTemp, 3, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 12)) = 'integration:' then
    begin
      LastCommittedFunction.IntegrationPackage :=
        Trim(copy(sTemp, 13, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 7)) = 'intype:' then
    begin
      LastCommittedFunction.InType := Trim(copy(sTemp, 8, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 8)) = 'outtype:' then
    begin
      LastCommittedFunction.Outtype := Trim(copy(sTemp, 9, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 11)) = 'visibility:' then
    begin
      LastCommittedFunction.Visibility := Trim(copy(sTemp, 12, length(sTemp)));
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else if lowercase(copy(sTemp, 1, 2)) = 'p:' then
    begin
      splitstring(Trim(copy(sTemp, 3, length(sTemp))), ':', sLeft, sRight);
      LastCommittedFunction.Parameters.Add(sLeft, sRight);
      LastCommittedFunction.Documentation.Delete
        (LastCommittedFunction.Documentation.count - 1);
    end
    else
    begin
      // lastCommittedFunction.Documentation.text := lastCommittedFunction.Documentation.text + #13#10;
    end;
    LastCommittedFunction.Documentation.text :=
      LastCommittedFunction.Documentation.text + #13#10;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchPropertyDeclaration;
begin
  CurrentSignature := CurrentSignature + CurChar;

  if (Stack.Current = pcPropertyDeclarationName) and (CurChar in validnames)
  then
    self.CurrentProperty := self.CurrentProperty + CurChar;

  //todo 1: this is a little dumb in that it basically just waits for a semicolon
  //handling  the read and write declarations of all properties
  if CurChar = ';' then
  begin
    AssertCurrentUnitState;
    CommitProperty;
    AssertCurrentUnitState;
    Stack.Pop;
    AssertCurrentUnitState;
  end;

  // TODO: Enhance
  if CurChar = ':' then
  begin
    Stack.Pop;
    Stack.Push(pcPropertyDeclarationResult);
  end;
  if CurChar = '[' then
  begin
    if Stack.Current = pcPropertyDeclarationName then
    begin
      Stack.Pop;
      Stack.Push(pcPropertyDeclaration);
    end;
    Stack.Push(pcBrackets);
  end;
end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchAncestorList;
var
  s: string;
begin

  s := Trim(FCurrentAncestor);
  if CurChar = ')' then
  begin
    if s <> '' then
      CurrentClass.AddAncestor(s);
    Stack.Pop;
    exit;
  end;

  if CurChar = '<' then
  begin
    Stack.Push(pcAncestorTypeParameters);
  end
  else
  begin
    if CurChar = ',' then
    begin
      if s <> '' then
        CurrentClass.AddAncestor(s);
    end;

    FCurrentAncestor := FCurrentAncestor + CurChar;
  end;

end;

procedure TPascalCompiler.DispatchAncestorTypeParameters;
begin
  if CurChar = '>' then
    Stack.Pop;

end;

procedure TPascalCompiler.DispatchBrackets;
begin
  if Stack.Parent in [pcPropertyDeclaration, pcPropertyDeclarationName,
    pcPropertyDeclarationIndex] then
    CurrentSignature := CurrentSignature + CurChar;

  if CurChar = ']' then
    Stack.Pop;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DispatchCodeBlock;
begin
  if AtWord('begin') or AtWord('case') or AtWord('try') then
  begin
    self.Write('$newblock$');
    Stack.Push(pcCodeBlock);
  end;

  if AtEndOfWord('end') then
  begin
    self.Write('$endblock$');
    Stack.Pop;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.CommitProperty;
var
  prop: TPropertyDefinition;
begin
  if currentproperty = 'DataObject' then
    log('trap');
  write('$commit$');
  // frmDebug.ShowMessage(currentSignature);

  if self.CurrentClass = nil then
  begin
    log(self, 'WTF. CurrentClass is NIL on CommitProperty');
    exit;
  end;

  if CurrentProperty = '' then
  begin
    log(self, 'WTF. CurrentProperty is NIL on CommitProperty');
    exit;
  end;

  IF self = nil then
    raise Exception.Create('wtf, SELF is nil!');

  IF self.CurrentClass = nil then
    raise Exception.Create('wtf, SELF.currentclass is nil!');

  var cc := self.CurrentClass;

  prop := cc.AddProperty(CurrentProperty, self);
  prop.fil := extractfilename(filename);
  prop.col := 0;
  prop.row := 0;
  prop.position := self.position;
  prop.Signature := CurrentSignature;

  self.LastCommittedProperty := prop;

end;

procedure TPascalCompiler.PropDoc(sString: string);
begin
  if self.CurrentSymbol <> nil then
  begin
    LastCommittedProperty.Documentation.text :=
      copy(LastCommittedProperty.Documentation.text, 1,
      length(LastCommittedProperty.Documentation.text) - 2) + sString;
  end;
end;

procedure TPascalCompiler.PropDocNewLine;
var
  sTemp: string;
begin
  if self.LastCommittedProperty <> nil then
  begin

    // if the line starts with "R:" then convert to class responsibility
    sTemp := '';
    if lowercase(copy(sTemp, 1, 2)) = 'r:' then
    begin
      // currentsymbol.responsibilities.add(copy(sTemp, 3, length(sTemp)));
      // currentsymbol.documentation.delete(currentsymbol.documentation.count-1);
    end
    else
    begin
      LastCommittedProperty.Documentation.text :=
        LastCommittedProperty.Documentation.text + #13#10;
    end;
  end;

end;

procedure TPascalCompiler.PushSymbolContext(sym: TSymbol);
begin
  FSymbolStack.Add(sym);
end;

procedure TPascalCompiler.DispatchFunction;
begin
  if AtEndOfWord('function') or AtEndOfWord('procedure') or
    AtEndOfWord('destructor') or AtEndOfWord('constructor') then
  begin
    self.CurrentFunction := '';
    Stack.Push(pcFunctionImpName);
  end
  else if CurChar = '(' then
  begin
    Stack.Push(pcParens);
  end
  else if AtWord('begin') then
  begin
    self.Write('$newblock$');
    Stack.Pop;
    Stack.Push(pcCodeBlock);
    LastCommittedFunction := nil;
    LastCommittedProperty := nil;
  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.DisPatchFunctionImpName;
begin
  if (self.CurChar in validnames) or (self.CurChar = '.') then
    self.CurrentFunction := self.CurrentFunction + self.CurChar
  else if (self.CurChar in wordbreaks) and (not(CurChar = ' ')) then
  begin
    self.FindFunction(self.CurrentFunction);
    Stack.Pop;

  end;

end;

// ------------------------------------------------------------------------------
procedure TPascalCompiler.FindFunction(sName: string);
var
  iPos: integer;
  sClassName: string;
  sFunctionName: string;
begin
  // set t
  iPos := pos('.', sName);
  if iPos > 0 then
  begin
    sClassName := copy(sName, 1, iPos - 1);
    sFunctionName := copy(sName, iPos + 1, length(sName));
    self.CurrentSymbol := Project.Symbols.findSymbol(sClassName);
    if assigned(CurrentClass) then
      self.LastCommittedFunction := CurrentClass.FindFunction(sFunctionName);
  end
  else
  begin
    // set the current class to the current unit
    self.CurrentSymbol := self.CurrentUnit;
    self.LastCommittedFunction := CurrentClass.FindFunction(sName);
    self.LastCommittedProperty := nil;
  end;

end;


procedure TPascalCompiler.DispatchVarConst;
begin
  if AtWord('procedure') or AtWord('function') or AtWord('constructor') or
    AtWord('destructor') or AtWord('initialization') or AtWord('finalization')
    or AtWord('implementation') or AtWord('uses') or AtWord('const') or
    AtWord('var') then
  begin
    Stack.Pop;
    BlockAdvance;
  end;
end;

procedure TCompiler.BlockAdvance;
begin
  FBlockAdvance := true;
end;

procedure TPascalCompiler.DispatchString;
begin
  if AtEndOfPattern('''') then
    Stack.Pop;

end;

procedure TPascalCompiler.DispatchStruct;
begin

  raise Exception.Create('unimplemented');
  // TODO -cunimplemented: unimplemented block
end;

procedure TPascalCompiler.DispatchStructName;
begin

  raise Exception.Create('unimplemented');
  // TODO -cunimplemented: unimplemented block
end;

function TPascalCompiler.Compile(sFile: string): boolean;
var
  sym: TSymbol;
begin
  try
    result := inherited Compile(sFile);

    if assigned(FCurrentUnit) then
      FCurrentUnit.DebugHTML := Output;
  except
    on E: Exception do begin
      log(e.Message);
      FCurrentUnit.DebugHTML := E.message+' -- could not compile '+sFile;
    end;
  end;

end;

{ TContext }

function TContext.GetFullyQualifiedNameSpaceName: string;
begin
  result := GetParentContext;
  if namespacename = '' then
    exit;

  if result <> '' then
    result := result+'.'+namespacename
  else
    result := namespacename;

end;

function TContext.GetParentContext: string;
var
  s: string;
begin
  if parent <> nil then
    result := parent.GetFullyQualifiedNameSpaceName
  else
    result := '';
end;

end.
