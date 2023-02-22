unit unicodeart;

interface

uses
  typex, stringx;

function RenderProgressText(p: TProgress): string;

function GetTextBar(pct: single): string;


implementation

function RenderProgressText(p: TProgress): string;

begin
        var s := '`cA`'+floatprecision(p.PercentComplete*100,0)+'% '+GetTextBar(p.PercentComplete)+'`cF`';
        var unesc := getunescapedlength(s);
        exit('`r`'+s);
end;



function GetTextBar(pct: single): string;
const
  barcodes = '▂▃▄▅▆▇█▉▊▋▌▍▎▏▐■▓▒░';
begin


  var cnt := (trunc((pct*100)/10));
  result := '`cF``b0`'+StringRepeat('█',cnt);
  var hundo := pct*100;

  if cnt < 10 then begin
    var off10 := hundo-(trunc(hundo/10)*10);
    const colorwidth = 10;
    const charwidth = colorwidth/3;
    const COLOR_TYPES = 3;
    const ChAR_TYPES = 4;
    var offColor := off10-(trunc(off10/colorwidth)*colorwidth);
    var offChar := offColor-(trunc(offColor/charWidth)*charWidth);

    var part := trunc((offcolor/colorwidth)*COLOR_TYPES);
    var subpart := trunc((offChar/charwidth)*CHAR_TYPES);
//    subpart := 1;

    var csub := '';
    case subpart of
      0:csub := '░';
      1:csub := '▒';
      2:csub := '▓';
      3:csub := '█';
    else
      csub := 'x';
    end;

    case part of
      0:result := result + '`c8``b0`'+csub;
      1:result := result + '`c7``b8`'+csub;
      2:result := result + '`cF``b7`'+csub;
      3:result := result + '`cF`'+csub;
    else
      result := result + '!';
    end;
  end;



  result := result +'`c8``b0`'+StringRepeat('.',10-(cnt+1));
  result := '`cE``b0`['+result+'`cE``b0`]';

end;


end.
