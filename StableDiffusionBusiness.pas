unit StableDiffusionBusiness;

interface
 uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, dir, dirfile,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, StableDiffusionClient, helpers_stream,ColorBlending,
  Vcl.ExtCtrls, netencoding, IdCoder, IdCoder3to4, IdCoderMIME, pngimage, betterobject, Math.Vectors,
  Vcl.ComCtrls, stringx, jsonhelpers, numbers, typex, systemx, geometry, fastbitmap, debug;

const
  DENOISE_MASK_LAYERS = 8;
  STEPS_NEW_SCENE = 20;
  STEPS_CONTINUED_SCENE = 20;
type
  TSDResults = record
    json: IHolder<TJSON>;
    info: IHolder<TJSON>;
    img: IHolder<TStream>;
    procedure init;
  end;
  TMotionType = (mtZoom, mtSlide, mtZoomAndSlide);
  TMotionAndVector = record
    motionType: TMotionType;
    motionVector: Math.Vectors.TVector3D;

    class function CreateRandom: TMotionAndVector;static;
  end;

  TSDZoomTripWaypoint = record
    startsAtFrame: int64;
    prompt, negativeprompt: string;
    motion: TMotionAndVector;
    denoise: double;
    denoisevariance : double;
    variancespeed: double;
    procedure init;
    procedure Randomize;
  end;

  TSDBusiness = class(TBetterObject)
  public
    input, output, mask: TPicture;
    denoisemasks: Tarray<TPicture>;
    frame: int64;
    lastSeedGenerated: int64;
    function txtToImage(prompt,negativePrompt: string; iSteps: ni): TSDResults;
    procedure ZoomTrip(startingImage: TPicture; waypoints: TArray<TSDZoomTripWaypoint>; numframe: ni; FPS: double; guiupdate: TProc);
    procedure Reset;
    procedure WarpOutput(wp: TSDZoomTripWaypoint; fi: TFastBitmap; framerate: double; out warpmask: IHolder<TFastBitmap>);
    constructor Create; override;
    destructor Destroy; override;
    procedure SetMask(fbWillNotDestroy: TFastBitmap);
    procedure GenerateMask(detailMaskOptional: TFastBitmap);
    procedure GenerateCustomMask(detailMask: TFastBitmap);
    procedure ResaveFolder(sFolder: string);

  end;


implementation


{ TSDBusiness }

constructor TSDBusiness.Create;
begin
  inherited;
  input := TPicture.create;
  output := TPicture.create;
  mask := TPicture.create;
  setlength(denoisemasks,DENOISE_MASK_LAYERS);
  for var t := 0 to high(denoisemasks) do
    denoisemasks[t] := TPicture.create;

end;

destructor TSDBusiness.Destroy;
begin
  input.free;
  output.free;
  mask.free;
  for var t:= 0 to high(denoisemasks) do
    denoisemasks[t].free;

  inherited;
end;

procedure TSDBusiness.GenerateCustomMask(detailMask: TFastBitmap);
begin
  detailMask.SaveToFile_PNG(dllpath+'output\__.png');
  forcedirectories(dllpath+'output\');
  var fbm := TFastBitmap.create;
  try
    var layers := length(denoisemasks);
    fbm.width := 512;
    fbm.height := 512;
    fbm.New;
    fbm.canvas.clear(clWhite);

    var cx := fbm.width div 2;
    var cy := fbm.height div 2;
(*    fbm.canvas.Iterate(procedure (x,y: ni) begin
      var dist := sqrt(((cx-x)*(cx-x))+((cy-y)*(cy-y)));
      var pct := dist / (fbm.width / 2);
      pct := 1.0-pct;
      pct := Clamp(pct, 0.0,1.0);
      fbm.canvas.Pixels[x,y] := colorblend(clBlack,clWhite,pct);

    end);*)
//    SetMask(fbm);
    var d := high(denoisemasks);
    while d >= 0 do begin
      var fbmNew := TFastBitmap.CopyCreate(fbm);
      try
        fbm.canvas.Iterate(procedure (x,y: ni) begin
          var pct := (detailMask.canvas.pixels[x,y] and $FF / $FF);
          pct := pct;
          pct := Clamp(pct, 0.0,1.0);
          var base := (d * (1/length(denoisemasks)));
          pct := pct - base;
          pct := Clamp(pct, 0.0,1.0);
          pct := pct * Length(denoisemasks);
          if pct > 1.0 then pct := 1.0;
          fbmNew.canvas.Pixels[x,y] := colorblend(clBlack,clWhite,pct);
          fbm.canvas.Pixels[x,y] := colorblend(fbm.canvas.pixels[x,y],clBlack,pct);

        end);
        if d >=0 then begin
          debug.log(d.tostring());
           fbmNew.assigntopicture(denoisemasks[d]);
          denoisemasks[d].SaveToFile(dllpath+'output\_'+inttostr(d)+'.png');
          dec(d);
        end;
      finally
        fbmNew.free;
      end;
    end;




  finally
    fbm.free;
  end;
end;

procedure TSDBusiness.GenerateMask(detailMaskOptional: TFastBitmap);
begin
  if detailMaskOptional <> nil then begin
    GenerateCustomMask(detailMaskOptional);
    exit;
  end;
  forcedirectories(dllpath+'output\');
  var fbm := TFastBitmap.create;
  try
    fbm.width := 512;
    fbm.height := 512;
    fbm.New;
    var cx := fbm.width div 2;
    var cy := fbm.height div 2;
    fbm.canvas.Iterate(procedure (x,y: ni) begin
      var dist := sqrt(((cx-x)*(cx-x))+((cy-y)*(cy-y)));
      var pct := dist / (fbm.width / 2);
      pct := 1.0-pct;
      pct := Clamp(pct, 0.0,1.0);
      fbm.canvas.Pixels[x,y] := colorblend(clBlack,clWhite,pct);

    end);
    SetMask(fbm);
    for var d := 0 to high(denoisemasks) do begin
      fbm.canvas.Iterate(procedure (x,y: ni) begin
        var dist := sqrt(((cx-x)*(cx-x))+((cy-y)*(cy-y)));
        var pct := dist / sqrt(((fbm.width / 2)*(fbm.width / 2))+((fbm.height / 2)*(fbm.height / 2)));
        pct := 1.0-pct;
        pct := Clamp(pct, 0.0,1.0);
        var base := (d * (1/length(denoisemasks)));
        pct := pct - base;
        pct := Clamp(pct, 0.0,1.0);
        pct := pct * Length(denoisemasks);
        if pct > 1.0 then pct := 1.0;
        fbm.canvas.Pixels[x,y] := colorblend(clWhite,clBlack,pct);

      end);
      fbm.assigntopicture(denoisemasks[d]);
      denoisemasks[d].SaveToFile(dllpath+'output\_'+inttostr(d)+'.png');
    end;




  finally
    fbm.free;
  end;
end;

procedure TSDBusiness.ResaveFolder(sFolder: string);
var
  fi: TFileInformation;
begin
  var dir := TDirectory.CreateH(sFolder, '*.bmp', 0,0);
  while dir.o.GetNextFile(fi) do begin
      var fbm : IHolder<TFastBitmap> := THolder<TFastBitmap>.create(TFastBitmap.create);
      fbm.o.LoadFromFile(fi.FullName);
      fbm.o.EnableAlpha := false;
      fbm.o.SaveToFile_PNG(changefileext(fi.fullname,'.png'));
  end;
end;

procedure TSDBusiness.Reset;
begin
  frame := 0;
end;

procedure TSDBusiness.SetMask(fbWillNotDestroy: TFastBitmap);
begin
  fbWillNotDestroy.AssignToPicture(mask);
end;

function TSDBusiness.txtToImage(prompt,negativePrompt: string; iSteps: ni): TSDResults;
begin
  result.init;
  var str := TpdStableDiffusionClient.need.o.Txt2ImageStr(prompt,negativePrompt, isteps);
  var json := StrtoJsonH(str);
  var info := StrtoJsonH(json.o['info'].value);
  result.json := json;
  result.info := info;

  SaveStringAsFile('temp.txt',str);
  //memo1.lines.text := json.o.tojson;
  lastSeedGenerated := info.o['all_seeds'][0].value;

  if json.o.HasNode('images') then begin

    var img := json.o['images'][0].value;
    //var png := TImage.Create(nil);
    result.img := DecodeBAse64Stream(img);
  end;

end;

procedure TSDBusiness.WarpOutput(wp: TSDZoomTripWaypoint; fi: TFastBitmap; framerate: double; out warpmask: IHolder<TFastBitmap>);
begin
  warpmask := THolder<TFastBitmap>.create(TFastbitmap.Create);
  warpmask.o.width := fi.width;
  warpmask.o.height := fi.height;
  warpmask.o.new;
  var clKeep := clBlack;
  var clChange := clWhite;
  warpmask.o.canvas.Clear(clWhite);


  var framerateMultiplier := 30/framerate;
  var fiOrig := TFastBitmap.CopyCreate(fi);
  try
    var mv := wp.motion.motionvector * framerateMultiplier;
    case wp.motion.motionType of
      mtZoom: begin
        fi.ResizeImage(round(512*(1.0+mv.x)),round(512*(1.0+mv.y)));
        fi.ResizeCanvas(512,512,round(1.0+mv.x /2),round(1.0+mv.y/2), fiOrig);
        warpmask.o.ResizeImage(round(512*(1.0+mv.x)),round(512*(1.0+mv.y)));
        warpmask.o.ResizeCanvas(512,512,round(1.0+mv.x /2),round(1.0+mv.y/2), clChange);
        warpmask.o.Effect_LBloom;

      end;
      mtSlide: begin
        var i2 : IHolder<TFastBitmap> := THolder<TFastBitmap>.create(TFastBitmap.CopyCreate(fi));
        fi.Canvas.Paste(i2.o,round(mv.x*512),round(mv.y*512));

        var i3 : IHolder<TFastBitmap> := THolder<TFastBitmap>.create(TFastBitmap.CopyCreate(warpmask.o));
        warpmask.o.canvas.clear(clChange);
        warpmask.o.Canvas.Paste(i3.o,round(mv.x*512),round(mv.y*512));
        warpmask.o.Effect_LBloom;
      end;
      mtZoomAndSlide: begin
        fi.ResizeImage(round(512*(1.0+mv.z)),round(512*(1.0+mv.z)));
        var i2 : IHolder<TFastBitmap> := THolder<TFastBitmap>.create(TFastBitmap.CopyCreate(fi));
        fi.Canvas.Paste(i2.o,round(mv.x*512),round(mv.y*512));
        var i3 : IHolder<TFastBitmap> := THolder<TFastBitmap>.create(TFastBitmap.CopyCreate(warpmask.o));
        warpmask.o.canvas.clear(clChange);
        warpmask.o.Canvas.Paste(i3.o,round(mv.x*512),round(mv.y*512));
        fi.ResizeCanvas(512,512,round(1.0+mv.x /2),round(1.0+mv.y/2), fiOrig);
        warpmask.o.ResizeImage(round(512*(1.0+mv.x)),round(512*(1.0+mv.y)));
        warpmask.o.ResizeCanvas(512,512,round(1.0+mv.x /2),round(1.0+mv.y/2), clChange);
        warpmask.o.Effect_LBloom;
      end;


    end;
      warpmask.o.SaveToFile_PNG(dllpath+'output\__w.png');
  finally
    fiOrig.free;
  end;

end;

procedure TSDBusiness.ZoomTrip(startingImage: TPicture; waypoints: TArray<TSDZoomTripWaypoint>; numframe: ni; FPS: double; guiupdate: TProc);
var
  lastPic, thisPic: IHolder<TFastBitMap>;
const
  DIFMIN = 0.01;
  DIFMAX = 0.51;

begin
  var layerpic : IHolder<TFastBitmap> := THolder<TFastBitmap>.create(TFastBitmap.create);
  var tempPic: IHolder<TPicture> := THolder<TPicture>.create(TPicture.create);
  thispic := nil;
  lastpic := nil;
  var fails := 0;
  GenerateMask(nil);
  var maskStr : IHolder<TMemoryStream> := THolder<TMemoryStream>.create(TMemoryStream.create);
  mask.SavetoSTream(maskStr.o);
  var layermasks: TArray<IHolder<TMemoryStream>>;
  setlength(layermasks,length(denoisemasks));
  for var d := 0 to high(layermasks) do begin
    layermasks[d] := THolder<TMemoryStream>.create(TMemoryStream.create);
    denoisemasks[d].SavetoSTream(layermasks[d].o);
  end;

//  const ITERS_PER_LINE = 30*4;
  for var memidx := 0 to high(waypoints) do begin
    var steps := STEPS_NEW_SCENE;
    if lastpic = nil then  begin
      lastpic := THolder<TFastBitmap>.create(TFastBitmap.create);
      lastpic.o.FromPicture(startingImage);
      input.Assign(startingImage);
    end;
    var line := trimstr(waypoints[memidx].prompt);

    if line = '' then begin
      showmessage('done');
      exit;
    end;

    var t := 0;
    var ennd := numframe -1;
    if memidx < high(waypoints) then begin
      ennd := waypoints[memidx+1].startsAtFrame;
    end;
    while frame < ennd do begin
      var outfile := dllpath+'output\'+frame.tostring+'.png';
      if fileexists(outfile) then begin
        input.loadfromfile(outfile);
        inc(t);
        inc(frame);
        continue;
      end;
      try
        var denoise := waypoints[memidx].denoise;
        denoise := denoise + ((sin(waypoints[memidx].variancespeed)+1.0/2.0)*waypoints[memidx].denoisevariance);
        denoise := denoise * 0.65;
        if denoise > 0.95 then
          denoise := 0.95;



        debug.log(floatprecision(t,4)+' '+line);

//        if (t mod 3=0) then
          lastSeedGenerated :=  random($7fffffff);



          thispic := THolder<TFastBitmap>.create(TFastBitmap.create);
          thispic.o.width := input.Width;
          thispic.o.height := input.height;
          thispic.o.new;
          thispic.o.FromPicture(input);

          var generatedLayers: Tarray<IHolder<TFastBitmap>>;
          setlength(generatedlayers,length(layermasks));
          var fbmlayermasks: Tarray<IHolder<TFastBitmap>>;
          setlength(fbmlayermasks,length(layermasks));
          for var d := 0 to high(layermasks) do begin
            fbmlayermasks[d] := THolder<TFastBitmap>.create(TFastBitmap.create);
            fbmlayermasks[d].o.FromPicture(denoisemasks[d]);
          end;

          //generate layers for each denoise level (THERE ARE NO MASKS AT THIS POINT)
          for var d := 0 to high(layermasks) do begin
            lastSeedGenerated :=  random($7fffffff);
            var msInput : IHolder<TMemoryStream> := THolder<TMemoryStream>.create(TMemoryStream.create);
//            if (d=0) then begin
              input.SavetoStream(msInput.o);
//            end else begin
//              output.SavetoStream(msInput.o);
//            end;
            //var den := 1.0-(((STEPS-t)/STEPS) * ((STEPS-t)/STEPS));
            denoise := 1.0-(d / high(layermasks));
            denoise := denoise * 0.80;
            var str := TpdStableDiffusionClient.need.o.Image2ImageStr(msInput.o,nil{layermasks[d].o},denoise,line,waypoints[memidx].negativeprompt,steps,lastseedgenerated);
            var tempfbm := THolder<TFastBitmap>.create(TFastBitmap.create);
            ForceDirectories(dllpath+'output\');
            var json := StrtoJsonH(str);
            if json.o.HasNode('info') then begin
              var info := StrtoJsonH(json.o['info'].value);

              SaveStringAsFile('temp.txt',str);
              //memo1.lines.text := json.o.tojson;

              var img := json.o['images'][0].value;
              //var png := TImage.Create(nil);
              generatedlayers[d] := THolder<TFastBitmap>.create(TFastBitmap.create);
              tempPic.o.LoadFromStream(DecodeBAse64Stream(img).o);
              generatedlayers[d].o.FromPicture(tempPic.o);
              generatedlayers[d].o.SaveToFile_PNG('__'+inttostr(d)+'.png');
            end else begin
              raise Ecritical.create(str);
            end;

          end;
//          for var d := 0 to high(layermasks) do begin
//            generatedlayers[d] := THolder<TFastBitmap>.create(TFastBitmap.create);
//            generatedlayers[d].o.FromPicture(denoisemasks[d]);
//          end;


        //NOW USE THE MASKS FROM THE PREVIOUS FRAME TO MERGE IN THE DETAILS
          thispic.o.canvas.Iterate(procedure (x,y: ni) begin
            var usedOpacity := 0;
            for var l := 0 to high(layermasks) do begin
              var maskval := fbmlayermasks[l].o.canvas.pixels[x,y] and $ff;
              inc(usedOpacity, maskval);
              var cin := generatedlayers[l].o.canvas.pixels[x,y];
              var cout := colorblend(lastpic.o.canvas.pixels[x,y], cin, maskval/255);
              thispic.o.canvas.pixels[x,y] := cout;
              if usedOpacity >=255 then break;
            end;
          end);

          thispic.o.AssignToPicture(output);
          lastpic := thispic;
          if assigned(guiupdate) then begin
            SyncAnon(guiupdate);
          end;

        //frame generated warp everything
        inc(frame);
        fails := 0;

        steps := STEPS_CONTINUED_SCENE;
        lastpic.o.savetoFile_PNG(outfile);
        var warpmask: IHolder<TFastBitmap> := nil;
        WarpOutput(waypoints[memidx], thispic.o,FPS, warpmask);
        //thispic.o.savetoFile_PNG(outfile+'.warped.png');

        var maskpic := thispic.o.CopyCreateH(thispic);
        maskpic.o.Effect_MaskDetail;
{$DEFINE WARP_MASK}
{$IFDEF WARP_MASK}
        warpmask.o.savetoFile_PNG(dllpath+'output\__v.png');
        maskpic.o.canvas.Iterate(procedure(x,y: ni) begin
          var c := maskpic.o.canvas.pixels[x,y] and $ff;
          var cc := warpmask.o.canvas.pixels[x,y] and $ff;
          c := lesserof(c,cc);
          c := c or (c shl 8) or (c shl 16) or (c shl 24);
          maskpic.o.canvas.pixels[x,y] := c;
        end);

{$ENDIF}
        GenerateMask(maskpic.o);
        lastpic := thispic;
        thispic.o.AssignToPicture(input);

        if assigned(guiupdate) then begin
          SyncAnon(guiupdate);
        end;
        inc(t);
      except
        on E: Exception do begin
          debug.log(e.message);
        end;
      end;


    end;
  end;
end;

{ TSDResults }

procedure TSDResults.init;
begin
  json := nil;
  img := nil;
end;

{ TSDZoomTripWaypoint }

procedure TSDZoomTripWaypoint.init;
begin
  motion := TMotionAndVector.CreateRandom;
end;

procedure TSDZoomTripWaypoint.Randomize;
begin
  motion := TMotionAndVector.CreateRandom;
  denoise := random(1000)/1000;
  denoise := 0.4+(denoise * 0.4);
  variancespeed := random(1000)/500000;
  denoisevariance := 0.0;

end;

{ TMotionAndVector }

class function TMotionAndVector.CreateRandom: TMotionAndVector;
begin
  var ord := random(2);
  var mt := TMotionType(ord);
  result.motionType := mt;
  case mt of
    mtZoom: begin
      var rx := (random(6000)-3000)/1000;
      rx := rx * 0.005;
      result.motionVector := Math.vectors.Vector3D(rx,rx,rx,1);

    end;
    mtSlide: begin
      var rx := (random(6000)-3000)/1000;
      var ry := (random(6000)-3000)/1000;
      rx := rx * 0.005;
      ry := ry * 0.005;
      result.motionVector := Math.vectors.Vector3D(rx,ry,0,1);
    end;
    mtZoomAndSlide: begin
      var rx := (random(6000)-3000)/1000;
      var ry := (random(6000)-3000)/1000;
      var rz := (random(6000)-3000)/1000;
      rx := rx * 0.005;
      ry := ry * 0.005;
      ry := rz * 0.005;
      result.motionVector := Math.vectors.Vector3D(rx,ry,rz,1);

    end;

  end;

  result.motionvector.w := 0;
  if result.motionVector.Length < 0.001 then
    result.motionvector := result.motionvector.Normalize * 0.001;






end;

end.
