unit StableDiffusionClient;

interface

uses
  HTTPClient_2020, betterobject, typex,systemx,stringx,JSONHelpers, HTTPTypes, classes, helpers_stream ;


type
  TpdStableDiffusionClient = class(TBetterObject)
  public
    baseurl: string;
    function NeedClient: IHolder<TStatefulBrowser>;
    function Txt2ImageStr(sPrompt, sNegativePrompt: string; iSteps: ni): string;
    function Image2ImageStr(input, mask: TStream; blend: double; sPrompt, sNegativePrompt: string; isteps: ni; seed: int64 = -1): string;
    function Txt2ImageJ(sPrompt, sNegativePrompt: string; iSteps: ni): IHolder<TJSON>;

    procedure Init; override;
    class function Need: IHolder<TpdStableDiffusionClient>;
  end;


implementation

{ TpdStableDiffusionClient }



function TpdStableDiffusionClient.Image2ImageStr(input: TStream; mask: TStream; blend: double; sPrompt,
  sNegativePrompt: string; isteps: ni; seed: int64 = -1): string;
var
  res: THTTPResults;
begin
  input.seek(0,soBeginning);
  var cli := needclient;
  var str :=
    '{'+
    '  "init_images": ['+
    '    "'+EncodeBase64Stream(input)+'"'+
    '  ],'+
    '  "resize_mode": 0,'+
    '  "denoising_strength": '+JSONValueString(blend)+','+
    BoolToStrAnon(mask<>nil,
      function:string begin
        exit('  "mask": '+JSONValueString(EncodeBase64Stream(mask))+',')
      end,
      nil
    )+
    '  "mask_blur": 4,'+
    '  "inpainting_fill": 0,'+
    '  "inpaint_full_res": true,'+
    '  "inpaint_full_res_padding": 0,'+
    '  "inpainting_mask_invert": 0,'+
    '  "prompt": '+JSONValueString(sPrompt)+','+
    '  "styles": ['+
    '    ""'+
    '  ],'+
    '  "seed": '+JSONValueString(seed)+','+
    '  "subseed": -1,'+
    '  "subseed_strength": 0,'+
    '  "seed_resize_from_h": -1,'+
    '  "seed_resize_from_w": -1,'+
    '  "sampler_name": "Euler a",'+
    '  "batch_size": 1,'+
    '  "n_iter": 1,'+
    '  "steps": '+JSONValueString(isteps)+','+
    '  "cfg_scale": 14,'+
    '  "width": 512,'+
    '  "height": 512,'+
    '  "restore_faces": false,'+
    '  "tiling": false,'+
    '  "negative_prompt": '+JSONValueString(sNegativePrompt)+','+
    '  "eta": 0,'+
    '  "s_churn": 0,'+
    '  "s_tmax": 0,'+
    '  "s_tmin": 0,'+
    '  "s_noise": 1,'+
    '  "override_settings": {},'+
    '  "sampler_index": "Euler a",'+
    '  "include_init_images": false'+
    '}';

  res := cli.o.Post(baseurl+'img2img',   str, 'application/json');
  result := res.body;




end;

procedure TpdStableDiffusionClient.Init;
begin
  inherited;
  baseurl := 'https://spotafry.com/sdapi/v1/';
end;

class function TpdStableDiffusionClient.Need: IHolder<TpdStableDiffusionClient>;
begin
  result := THolder<TpdStableDiffusionClient>.create( TpdStableDiffusionClient.create);
end;

function TpdStableDiffusionClient.NeedClient: IHolder<TStatefulBrowser>;
begin
  result := THolder<TStatefulBrowser>.create(TStatefulBrowser.create());

end;

function TpdStableDiffusionClient.Txt2ImageJ(sPrompt, sNegativePrompt: string; iSteps: ni): IHolder<TJSON>;
begin
  result := StrToJSONh(Txt2ImageStr(sPrompt, sNegativePrompt,isteps));



end;

function TpdStableDiffusionClient.Txt2ImageStr(sPrompt,
  sNegativePrompt: string; iSteps: ni): string;
var
  res: THTTPResults;
begin
  var cli := needclient;
  var str := '{'+
    '  "enable_hr": false, '+
    '  "denoising_strength": 0, '+
    '  "firstphase_width": 0, '+
    '  "firstphase_height": 0, '+
    '  "prompt": '+JSONValueString(sPrompt)+', '+
    '  "styles": [ '+
    '    "" '+
    '  ], '+
    '  "seed": -1, '+
    '  "subseed": -1, '+
    '  "subseed_strength": 0, '+
    '  "seed_resize_from_h": -1, '+
    '  "seed_resize_from_w": -1, '+
    '  "sampler_name": "Euler a", '+
    '  "batch_size": 1, '+
    '  "n_iter": 1, '+
    '  "steps": '+JSONValueString(isteps)+', '+
    '  "cfg_scale": 14, '+
    '  "width": 512, '+
    '  "height": 512, '+
    '  "restore_faces": false, '+
    '  "tiling": false, '+
    '  "negative_prompt": '+JSONValueString(sNegativePrompt)+', '+
    '  "eta": 0, '+
    '  "s_churn": 0, '+
    '  "s_tmax": 0, '+
    '  "s_tmin": 0, '+
    '  "s_noise": 1, '+
    '  "override_settings": {}, '+
    '  "sampler_index": "Euler a" '+
    '}';
  res := cli.o.Post(baseurl+'txt2img',   str, 'application/json');
  result := res.body;




end;

end.
