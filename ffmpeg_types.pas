unit ffmpeg_types;

interface

uses
  betterobject, classes, sysutils, stringx, typex;

type

  TBleedingEdge = (beAncientDeprecated, beStable, be4kEra, beVidStab);
  TFFMPEG_Action = (ffExtractFrame,ffExtractFrames, ffToDmxVideo, ffToMp3, ffExtractAudioChannels, ffToChromecastLQ, ffToChromecastHQ, ffToChromecastOQ, ffToChromeCastUQ, ffToOculus,ffProbe, ffSwapCR, ffVidStab1, ffVidStab2);

  TFFProbe = record
  strict private
    procedure AnalyzeAudioDescriptors;
    procedure AnalyzeVideoDescriptors;
  public
    w,h: single;
    hasvideo: boolean;
    VideoCodec: string;
    VideoCodecEx: string;
    AudioCodec: string;
    AudioCodecEx: string;
    AudioChannels: integer;
    AudioSubStream: integer;
    VideoSubStream: integer;
    AudioDescriptors: IHolder<TstringList>;
    VideoDescriptors: IHolder<TStringList>;
    debugString: string;
    procedure Init;
    procedure Parse(stext: string);
    function ToString: string;
    function Is5_1: boolean;
    function Is7_1: boolean;
    function Valid: boolean;
  end;


implementation


{ TFFProbe }

procedure TFFProbe.AnalyzeAudioDescriptors;
begin
  //cycle through string list and set flags and parameters based on what we find
  AudioChannels := 1;
  for var t:=0 to self.AudioDescriptors.o.Count-1 do begin
    var s := self.AudioDescriptors.o[t];
    s := lowercase(s);
    if zpos('2ch', s) >=0 then
      AudioChannels := 2;
    if zpos('2.1', s) >=0 then
      AudioChannels := 3;
    if zpos('3.1', s) >=0 then
      AudioChannels := 4;
    if zpos('stereo', s) >=0 then
      AudioChannels := 2;
    if zpos('5.1', s) >=0 then
      AudioChannels := 6;
    if zpos('7.1', s) >=0 then
      AudioChannels := 8;
  end;

end;

procedure TFFProbe.AnalyzeVideoDescriptors;
begin
  //
end;

procedure TFFProbe.Init;
begin
  w := 0;
  h := 0;
  audiochannels := -1;
  hasvideo := true;

end;

function TFFProbe.Is5_1: boolean;
begin
  result := zpos('5.1', AudioCodecEx) >=0;
end;

function TFFProbe.Is7_1: boolean;
begin
  result := zpos('7.1', AudioCodecEx) >=0;
end;

procedure TFFProbe.Parse(sText: string);
var
  junk, s, sl, sr: string;
  h: IHolder<TStringList>;
  t: ni;
begin
  debugString := sText;
  AudioDescriptors := nil;
  VideoDescriptors := nil;
  s := sText;
  if SplitString(s, 'Stream #0:', sl, sr) then begin
    if SplitString(sr, 'Video:', sl,sr) then begin
      sr := stringreplace(sr, CRLF, LF, [rfReplaceAll]);
      h := ParseStringh(sr, LF);
      if h.o.Count > 0 then begin
        h := ParseStringh(h.o[0], ',');
        for t:= 0 to h.o.count-1 do begin
          s := h.o[t];
          s := Trim(s);

          if SplitString(s, 'x', sl,sr) then begin
            SplitString(sr,' ',sr, junk);
            if IsInteger(sl) and IsInteger(sr) then begin
              self.w := strtofloat(sl);
              self.h := strtofloat(sr);
            end;
          end;
        end;
      end;

    end;
  end;

  //parse streams
  begin
    s := sText;
    for var x := 0 to 32 do begin
      for var y := 0 to 32 do begin
        //if we have such a stream
        if SplitString(s, 'Stream #'+x.ToString+':'+y.tostring+'(', sl,sr)
        or SplitString(s, 'Stream #'+x.ToString+':'+y.tostring+':', sl,sr)
        then begin
          //identify the stream type
          Splitstring(sr,#10, sl, sr);
          sl := trim(sl);
          if SplitString(sl, 'Video: ', sl, sr) then begin
            if videoDescriptors = nil then begin
              VideoSubStream := y;
              self.VideoCodecEx := sr;
              VideoDescriptors := ParseStringH(self.VideoCodecEx, ',');
              AnalyzeVideoDescriptors;
              SplitString(sr,',',self.VideoCodec, sr);
            end;
          end;
          if SplitString(sl, 'Audio: ', sl, sr) then begin
            if AudioDescriptors = nil then begin
              self.AudioCodecEx := sr;
              AudioSubStream := y;
              AudioDescriptors := ParseStringH(self.AudioCodecEx, ',');
              AnalyzeAudioDescriptors;
              SplitString(sr,',',self.AudioCodec, sr);
            end;
          end;

        end;
      end;
    end;

  end;
end;


function TFFProbe.ToString: string;
begin
  result := 'w: '+w.tostring+' h: '+h.tostring+NL+
            'Video: '+videocodec+'    '+
            'Audio: '+audiocodec+nl+
            'VideoEx: '+videocodecex+nl+
            'AudioEx: '+audiocodecex+nl+
            'AudioChannels: '+Self.AudioChannels.ToString;

end;

function TFFProbe.Valid: boolean;
begin
  result := (Audiochannels >=0) and (w>0) and (h>0);

end;


end.
