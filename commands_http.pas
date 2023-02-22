unit commands_http;

interface

uses
  betterobject, commandprocessor, httpclient, sysutils, tickcount, httpclient_2020, classes, helpers_stream, HTTPTypes;

type
  Tcmd_HTTPDownload = class(TCommand)
  private
    FURL: string;
    FTimeout: ticker;
    results:  THTTPResults;
    alternate_output_stream: IHolder<TStream>;
    function GetTimeout: ticker;
    procedure SetTimeout(const Value: ticker);
  public
    constructor Create;override;
    destructor Destroy;override;

    property URL: string read FURL write FURL;

    procedure DoExecute;override;
    procedure OnHTTPProgress(pos, max: int64);
    property Timeout: ticker read GetTimeout write SetTimeout;
  end;

  Tcmd_HTTPDownLoadToFile = class(Tcmd_HTTPDownload)
  private
    FFile: string;
  public
    IgnoreIfTargetExists: boolean;
    procedure InitExpense;override;
    procedure DoExecute;override;
    property LocalFile: string read FFile write FFile;
  end;




implementation


{ Tcmd_HTTPDownload }

constructor Tcmd_HTTPDownload.Create;
begin
  inherited;
  FTimeout := 300000;
end;

destructor Tcmd_HTTPDownload.Destroy;
begin
  inherited;
end;

procedure Tcmd_HTTPDownload.DoExecute;
begin
  inherited;
  status := 'GET '+url;

  results := HTTPSGet(URL,alternate_output_stream, self);
end;

function Tcmd_HTTPDownload.GetTimeout: ticker;
begin
  result := FTimeout;
end;

procedure Tcmd_HTTPDownload.OnHTTPProgress(pos, max: int64);
begin
  self.Step := pos;
  self.StepCount := max;
  self.NotifyProgress;
end;

procedure Tcmd_HTTPDownload.SetTimeout(const Value: ticker);
begin
  FTimeout := value;
end;

{ THTTPDownLoadToFileCommand }

procedure Tcmd_HTTPDownLoadToFile.DoExecute;
begin
  if (not IgnoreIfTargetExists) or (not FileExists(localfile)) then begin
    alternate_output_stream := THolder<TStream>.create;
    var fs := TFileStream.create(localfile, fmCreate);
    alternate_output_stream.o := fs;
    inherited;


    if results.bodystream =nil then
      exit;
    if results.bodystream.o = nil then
      exit;

{    var fs := TFileStream.create(localfile, fmCreate);
    try
      results.bodystream.o.Seek(0, soBeginning);
      Stream_GuaranteeCopy(results.bodystream.o, fs, results.bodystream.o.Size);
    finally
      fs.free;
    end;
 }


  end;

end;


procedure Tcmd_HTTPDownLoadToFile.InitExpense;
begin
//  inherited;
  NetworkExpense := 1/8;
end;

end.
