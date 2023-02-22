unit SoundConversion;
{$Message '********************************Compiling SoundConversion'}

interface
{$IFDEF MSWINDOWS}
{$IFNDEF MSWINDOWS}
  {$ERROR 'only supported on windows'}
{$ENDIF}

uses
  numbers, systemx, classes, debug,
{$IFDEF MSWINDOWS}
  msacm, mmsystem,
{$ENDIF}
  soundinterfaces, multibuffermemoryfilestream, typex, sounddevice_mm, sysutils, helpers_stream, stringx;

type
  TStreamType = TMultiBufferMemoryFileStream;

type
  TMemorySoundInfo = record
    SampleRate: integer;
    SampleCount: int64;
    Channels: integer;
    stream: TMemoryStream;
  end;


function ScaleRawSampleBuffer(buf1,buf2: PByte; buf1sz: integer; scale: double; var totalsamplesconverted: int64): nativeint;

function MP3ToRawMemoryStreamDeprecatedXXX(sMP3File: string; out info: TMp3info): TMemoryStream;
function MP3ToRawMemoryStreamFixed2020(sMP3File: string; out info: TMp3info): TMemoryStream;

function MP3ToRawMemoryStream2020Flailed(sMP3File: string; desiredsamplerate: integer; desiredchannels: integer): TMemorySoundInfo;

{$ENDIF}
implementation

uses
  soundtools;


function ScaleRawSampleBuffer(buf1,buf2: PByte; buf1sz: integer; scale: double; var totalsamplesconverted: int64): nativeint;
type
  cast = Array of T16BitStereoSoundsample;
  pcast = ^T16BitStereoSoundsample;
  P16BitStereoSoundSample = ^T16BitStereoSoundsample;
var
  ss: T16BitStereoSoundSample;
  a,b: PByte;
begin
  var buf2sz := round(buf1sz * scale);
  result := buf2sz;
  a := buf1;
  b := buf2;
  for var t:= 0 to buf2sz-1 do begin
    var srcidx := round(t / scale);
    a := buf1+(srcidx*sizeof(T16BitStereoSoundSample));
    b := buf2+(t*sizeof(T16BitStereoSoundSample));
    ss := P16BitStereoSoundSample(a)^;
    inc(totalsamplesconverted);
    P16BitStereoSoundSample(b)^ := ss;
  end;


end;

{$IFDEF MSWINDOWS}
function MP3ToRawMemoryStream2020Part(instream: TStream; var info: TMemorysoundInfo): int64;
//BECAUSE mp3s are (potentially) variable rate, we have to seek out an individual frame,
//and convert it into our desired format
const
  MP3_BLOCK_SIZE = 522 div 1;
var
  wf2: TWaveFormatEx;
  wf1: Tmpeglayer3waveformat_tag;
  has: HACMStream;
  ash: TACMSTREAMHEADER;
{  targetsize: cardinal;
  bufSource, bufTarget: PByte;
  mmr: cardinal;
  fsin: TStreamType;
  iToRead: nativeint;
  iRead: nativeint;
  f: dword;
  iPos: int64;}
  mp3info: TMp3Info;
begin
  if GetMp3Info(instream, {out}mp3Info,true) then begin
//    var mp3sz := mp3info.id3header.size;
//    debug.log('size :'+mp3info.id3header.size.tostring);
    debug.log(mp3info.samplerate.tostring());
    wf2 := GetStandardWaveFormat({info.samplerate}mp3info.samplerate);
    FillMem(Pbyte(@wf1), sizeof(wf1), 0);

    wf1.wfx.cbSize := MPEGLAYER3_WFX_EXTRA_BYTES;
    wf1.wfx.wFormatTag := WAVE_FORMAT_MPEGLAYER3;
    wf1.wfx.nChannels := 2;
    wf1.wfx.nAvgBytesPerSec := 128;//128 * (1024 div 8);  // not really used but must be one of 64, 96, 112, 128, 160kbps
    wf1.wfx.wBitsPerSample := 0;                  // MUST BE ZERO
    wf1.wfx.nBlockAlign := 1;                     // MUST BE ONE

    wf1.wfx.nSamplesPerSec := mp3info.samplerate;              // 44.1kHz
    wf1.fdwFlags := MPEGLAYER3_FLAG_PADDING_OFF;
    wf1.nBlockSize := MP3_BLOCK_SIZE;             // voodoo value #1
    wf1.nFramesPerBlock := 1;                     // MUST BE ONE
    wf1.nCodecDelay := 0;//1393;                      // voodoo value #2
    wf1.wID := MPEGLAYER3_ID_MPEG;
    var mmr := acmStreamOpen(@has, 0, @wf1.wfx, @wf2, nil, nil, nil, 0);
    if mmr <> 0 then begin
      exit(0);
//      raise Exception.Create('assert '+inttostr(mmr));
    end;
    var targetsize: cardinal;
    mmr := acmStreamSize(has, MP3_BLOCK_SIZE, {out}targetsize, ACM_STREAMSIZEF_SOURCE);
    var bufTarget : PByte := GetMemory(targetsize);
    try
        var bufSource : PByte := GetMemory(wf1.nBlockSize);
        try

          FillMem(Pbyte(@ash), sizeof(ash), 0);                         //  ZeroMemory( &mp3streamHead, sizeof(ACMSTREAMHEADER ) );
          ash.cbStruct := sizeof(TACMSTREAMHEADER);              //  mp3streamHead.cbStruct = sizeof(ACMSTREAMHEADER );
          ash.pbSrc := bufSource;                                //  mp3streamHead.pbSrc = mp3buf;
          ash.pbDst := bufTarget;                                //  mp3streamHead.pbDst = rawbuf;
          ash.cbSrcLength := wf1.nBlockSize;                     //  mp3streamHead.cbSrcLength = MP3_BLOCK_SIZE;
          ash.cbDstLength := targetsize;                         //  mp3streamHead.cbDstLength = rawbufsize;
          mmr := acmStreamPrepareHeader(has, @ash, 0);            //  mmr = acmStreamPrepareHeader( g_mp3stream, &mp3streamHead, 0 );

          var iPos := info.stream.Position;

          //Debug.Log(inttostr(fsIn.position)+':'+inttostr(fsIn.Size));
          var cx := instream.Size-instream.Position;
          while cx > 0 do begin
            var iToRead := lesserof(instream.Size-instream.Position, lesserof(cx,wf1.nBlockSize));
            if iToRead = 0 then
              break;
            var iJustRead := Stream_GuaranteeRead(instream, @bufSource[0], iToRead);
            ash.cbSrcLengthUsed := iJustRead;
            var flags := ACM_STREAMCONVERTF_BLOCKALIGN;
            if cx = instream.Size-instream.Position then
              flags := flags or ACM_STREAMCONVERTF_START;
            dec(cx,iJustRead);
            if cx <= 0 then
              flags := flags or ACM_STREAMCONVERTF_END;
            ash.cbDstLengthUsed := 0;
            mmr := acmStreamConvert(has, ash,flags);
            if (mmr = 0) {or (ash.cbDstLengthUsed > 0 )} then begin

              if ash.cbDstLengthUsed <> 0 then begin
                if (false) or (int64(mp3info.samplerate) = int64(info.samplerate)) then begin
                  Stream_GuaranteeWrite(info.stream, bufTarget, ash.cbDstLengthUsed);
                  inc(info.samplecount,ash.cbDstLengthUsed div sizeof(T16BitStereoSoundSample));

                end else begin
                  var scale := info.SampleRate/mp3info.samplerate;
                  //scale := 1.0;

                  var bufIntermediate: PByte := GetMemory(round((scale)*targetsize)+2048);
                  try
                    var toWrite := ScaleRawSampleBuffer(bufTarget, bufIntermediate, ash.cbDstLengthUsed,scale, info.samplecount);

                    Stream_GuaranteeWrite(info.stream, bufIntermediate, toWrite)

                  finally
                    FreeMemory(bufIntermediate)
                  end;
                end;
              end;
            end else
              debug.log('bad mmr ='+mmr.tostring);
          end;

          acmStreamUnprepareHeader(has, @ash, 0);
        finally
          FreeMemory(bufSource);
        end;
    finally
      FreeMemory(bufTarget);
    end;



    exit(1);
  end else
    exit(0);

end;


function MP3ToRawMemoryStream2020Flailed(sMP3File: string; desiredsamplerate: integer; desiredchannels: integer): TMemorySoundInfo;
begin
  result.SampleRate := desiredsamplerate;
  result.Stream := TMemoryStream.create;
  result.samplecount := 0;
  result.stream.Seek(0,0);
  result.channels := desiredchannels;

  var fsIn := TStreamType.Create(sMp3File, fmOpenRead+fmShareDenyWrite);
  try
    fsIn.BufferSize := 2000000;
    var f: cardinal;
    while Mp3ToRawMemoryStream2020Part(fsin,result) > 0 do begin

    end;
  finally
    fsIn.free;
  end;

  Debug.Log('converted mp3 into '+commaize(result.samplecount) + ' samples at '+result.samplerate.tostring+'hz ('+floatprecision(result.samplecount/result.samplerate,2)+' seconds)');





end;

function MP3ToRawMemoryStreamDeprecatedXXX(sMP3File: string; out info: TMp3info): TMemoryStream;
const
  MP3_BLOCK_SIZE = 522 div 1;
var
  wf2: TWaveFormatEx;
  wf1: Tmpeglayer3waveformat_tag;
  has: HACMStream;
  ash: TACMSTREAMHEADER;
  targetsize: cardinal;
  bufSource, bufTarget: PByte;
  mmr: cardinal;
  fsin: TStreamType;
  iToRead: nativeint;
  iRead: nativeint;
  f: dword;
  iPos: int64;
  mp3info: TMp3Info;
begin
  result := nil;
  try
  fsIn := TStreamType.Create(sMp3File, fmOpenRead+fmShareDenyWrite);
    try

      fsIn.BufferSize := 2000000;
      result := TMemoryStream.Create;
      result.Seek(0,0);
      //mp3info.samplerate := 22050;
      getMp3Info(fsIn, mp3info,true);


  {x$DEFINE FORCE_MP3_44100}
  {$IFDEF FORCE_MP3_44100}mp3info.samplerate := 44100;{$ENDIF}

      wf2 := GetStandardWaveFormat({$IFDEF FORCE_MP3_44100}44100{$ELSE}mp3info.samplerate{$ENDIF});
      FillMem(Pbyte(@wf1), sizeof(wf1), 0);


      wf1.wfx.cbSize := MPEGLAYER3_WFX_EXTRA_BYTES;
      wf1.wfx.wFormatTag := WAVE_FORMAT_MPEGLAYER3;
      wf1.wfx.nChannels := 2;
      wf1.wfx.nAvgBytesPerSec := 128;//128 * (1024 div 8);  // not really used but must be one of 64, 96, 112, 128, 160kbps
      wf1.wfx.wBitsPerSample := 0;                  // MUST BE ZERO
      wf1.wfx.nBlockAlign := 1;                     // MUST BE ONE

      wf1.wfx.nSamplesPerSec := mp3info.samplerate;              // 44.1kHz
      wf1.fdwFlags := MPEGLAYER3_FLAG_PADDING_OFF;
      wf1.nBlockSize := MP3_BLOCK_SIZE;             // voodoo value #1
      wf1.nFramesPerBlock := 1;                     // MUST BE ONE
      wf1.nCodecDelay := 0;//1393;                      // voodoo value #2
      wf1.wID := MPEGLAYER3_ID_MPEG;

      bufSource := GetMemory(wf1.nBlockSize);
      try
        mmr := acmStreamOpen(@has, 0, @wf1.wfx, @wf2, nil, nil, nil, 0);
        try
          if mmr <> 0 then
            raise Exception.Create('assert '+inttostr(mmr));
          mmr := acmStreamSize(has, MP3_BLOCK_SIZE, targetsize, ACM_STREAMSIZEF_SOURCE);
          bufTarget := GetMemory(targetsize);

          try
      //  ACMSTREAMHEADER mp3streamHead;



            FillMem(Pbyte(@ash), sizeof(ash), 0);                         //  ZeroMemory( &mp3streamHead, sizeof(ACMSTREAMHEADER ) );
            ash.cbStruct := sizeof(TACMSTREAMHEADER);              //  mp3streamHead.cbStruct = sizeof(ACMSTREAMHEADER );
            ash.pbSrc := bufSource;                                //  mp3streamHead.pbSrc = mp3buf;
            ash.pbDst := bufTarget;                                //  mp3streamHead.pbDst = rawbuf;
            ash.cbSrcLength := wf1.nBlockSize;                     //  mp3streamHead.cbSrcLength = MP3_BLOCK_SIZE;
            ash.cbDstLength := targetsize;                         //  mp3streamHead.cbDstLength = rawbufsize;
            mmr := acmStreamPrepareHeader(has, @ash, 0);            //  mmr = acmStreamPrepareHeader( g_mp3stream, &mp3streamHead, 0 );

              try
                while fsIn.Position < fsIn.Size do begin
                  //iPos := fsIn.Position;
                  var mp3infox: TMp3Info;
                  if Getmp3info(fsIn,mp3infox,false) then
                    wf1.wfx.nSamplesPerSec := mp3infox.samplerate
                  else begin
                    fsIn.Seek(1,soCurrent);
                    continue;
                  end;

                  iToRead := lesserof(fsIn.Size-fsIn.Position, wf1.nBlockSize);
                  //Debug.Log(inttostr(fsIn.position)+':'+inttostr(fsIn.Size));
                  iRead := Stream_GuaranteeRead(fsIn, @bufSource[0], iToRead);
                  ash.cbSrcLengthUsed := iRead;
                  f := 0;
                  if result.Position = 0 then
                    f := ACM_STREAMCONVERTF_START;
                  if (iRead < iToRead) then
                    f := f + ACM_STREAMCONVERTF_END;
                  mmr := acmStreamConvert(has, ash,ACM_STREAMCONVERTF_BLOCKALIGN+ f);
                  if mmr <> 0 then
                    Debug.log('convert failed mmr = '+mmr.tostring());
                  if ash.cbDstLengthUsed <> 0 then
                    Stream_GuaranteeWrite(result, bufTarget, ash.cbDstLengthUsed);

                end;

            finally
              acmStreamUnprepareHeader(has, @ash, 0);
            end;
          finally
            FreeMemory(bufTarget);
          end;
        finally
          mmr := acmStreamClose(has, 0);
        end;
      finally
        FreeMemory(bufSource);
      end;

      info := mp3info;
    finally
      fsIn.Free;
    end;

  except
    result.free;
    result := nil;
    raise;
  end;
end;


function MP3ToRawMemoryStreamFixed2020(sMP3File: string; out info: TMp3info): TMemoryStream;
const
  MP3_BLOCK_SIZE = 522 div 1;
type
  TStreamType = TMultiBufferMemoryFileStream;
var
  wf2: TWaveFormatEx;
  wf1: Tmpeglayer3waveformat_tag;
  has: HACMStream;
  ash: TACMSTREAMHEADER;
  targetsize: cardinal;
  bufSource, bufTarget: PByte;
  mmr: cardinal;
  fsin: TStreamType;
  iToRead: nativeint;
  iRead: nativeint;
  f: dword;
  iPos: int64;
  mp3info: TMp3Info;
begin
  result := nil;
  try
    mp3info := Getmp3info(smp3File);
    //mp3info.samplerate := 22050;

//    if outputsamplerate = 0 then
//      outputsamplerate := mp3info.samplerate;

    wf2 := GetStandardWaveFormat(mp3info.samplerate);
    FillMem(Pbyte(@wf1), sizeof(wf1), 0);



    wf1.wfx.cbSize := MPEGLAYER3_WFX_EXTRA_BYTES;
    wf1.wfx.wFormatTag := WAVE_FORMAT_MPEGLAYER3;
    wf1.wfx.nChannels := 2;
    wf1.wfx.nAvgBytesPerSec := 128;//128 * (1024 div 8);  // not really used but must be one of 64, 96, 112, 128, 160kbps
    wf1.wfx.wBitsPerSample := 0;                  // MUST BE ZERO
    wf1.wfx.nBlockAlign := 1;                     // MUST BE ONE
    wf1.wfx.nSamplesPerSec := mp3info.samplerate;              // 44.1kHz
    wf1.fdwFlags := MPEGLAYER3_FLAG_PADDING_OFF;
    wf1.nBlockSize := MP3_BLOCK_SIZE;             // voodoo value #1
    wf1.nFramesPerBlock := 1;                     // MUST BE ONE
    wf1.nCodecDelay := 0;//1393;                      // voodoo value #2
    wf1.wID := MPEGLAYER3_ID_MPEG;

    bufSource := GetMemory(wf1.nBlockSize);
    try
      mmr := acmStreamOpen(@has, 0, @wf1.wfx, @wf2, nil, nil, nil, 0);
      try
        if mmr <> 0 then
          raise Exception.Create('assert '+inttostr(mmr));
        mmr := acmStreamSize(has, MP3_BLOCK_SIZE, targetsize, ACM_STREAMSIZEF_SOURCE);
        bufTarget := GetMemory(targetsize);

        try
    //  ACMSTREAMHEADER mp3streamHead;



          FillMem(Pbyte(@ash), sizeof(ash), 0);                         //  ZeroMemory( &mp3streamHead, sizeof(ACMSTREAMHEADER ) );
          ash.cbStruct := sizeof(TACMSTREAMHEADER);              //  mp3streamHead.cbStruct = sizeof(ACMSTREAMHEADER );
          ash.pbSrc := bufSource;                                //  mp3streamHead.pbSrc = mp3buf;
          ash.pbDst := bufTarget;                                //  mp3streamHead.pbDst = rawbuf;
          ash.cbSrcLength := wf1.nBlockSize;                     //  mp3streamHead.cbSrcLength = MP3_BLOCK_SIZE;
          ash.cbDstLength := targetsize;                         //  mp3streamHead.cbDstLength = rawbufsize;
          mmr := acmStreamPrepareHeader(has, @ash, 0);            //  mmr = acmStreamPrepareHeader( g_mp3stream, &mp3streamHead, 0 );
          try
            fsIn := TStreamType.Create(sMp3File, fmOpenRead+fmShareDenyWrite);
            fsIn.BufferSize := 2000000;
            result := TMemoryStream.Create;
            result.Seek(0,0);
            try
              while fsIn.Position < fsIn.Size do begin
                iPos := result.Position;
                iToRead := lesserof(fsIn.Size-fsIn.Position, wf1.nBlockSize);
                //Debug.Log(inttostr(fsIn.position)+':'+inttostr(fsIn.Size));
                iRead := Stream_GuaranteeRead(fsIn, @bufSource[0], iToRead);
                ash.cbSrcLengthUsed := iRead;
                f := 0;
                if fsIn.Position = 0 then
                  f := ACM_STREAMCONVERTF_START;
                if (iRead < iToRead) or (fsIn.Position = fsIn.Size) then
                  f := f + ACM_STREAMCONVERTF_END;
                mmr := acmStreamConvert(has, ash,ACM_STREAMCONVERTF_BLOCKALIGN+ f);
                if ash.cbDstLengthUsed <> 0 then
                  Stream_GuaranteeWrite(result, bufTarget, ash.cbDstLengthUsed);


              end;
            finally
              fsIn.Free;
            end;

          finally
            acmStreamUnprepareHeader(has, @ash, 0);
          end;
        finally
          FreeMemory(bufTarget);
        end;
      finally
        mmr := acmStreamClose(has, 0);
      end;
    finally
      FreeMemory(bufSource);
    end;

    info := mp3info;
  except
    result.free;
    result := nil;
    raise;
  end;
end;
{$ENDIF}



end.
