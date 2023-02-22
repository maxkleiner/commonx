unit HTTPTypes;

//Represents a platform agnostic abstraction of HTTPs, but does not
//specify an implementation


interface


uses
  systemx, stringx, betterobject, typex, classes, system.net.urlclient;

type
  TExtraHeader = record
    name: string;
    value: string;
    class function make(n,v: string): TExtraHeader;static;
  end;
  THttpsMethod = (mGet, mPost, mPatch);
  THTTPSRequest = record
    addHead: string;
    addHeadValue: string;
    method: ThttpsMethod;
    acceptranges: string;
    contentlength: int64;
    range: string;
    url: string;
    PostData: string;
    Referer: string;
    Cookie: string;
    ContentType: string;
    PostBody: string;
  end;

  THTTPResults = record
    HoldInterface: IUnknown;//<--optional, hold onto some other interface to manage its lifetime
    ResultCode: ni;
    Body: string;
    Success: boolean;
    contentType: string;
    contentRange: string;
    error: string;
    cookie_headers: array of string;
    bodystream: IHolder<TStream>;
    native: IURLResponse;
    procedure AddCookieHeader(s: string);
    function ContentTypeIsText: boolean;
  end;



implementation



{ THTTPSRequest }



{ TExtraHeader }

class function TExtraHeader.make(n, v: string): TExtraHeader;
begin
  result.name := n;
  result.value := v;
end;

{ THTTPResults }

procedure THTTPResults.AddCookieHeader(s: string);
begin
  setlength(self.cookie_headers, length(self.cookie_headers)+1);
  cookie_headers[high(cookie_headers)] := s;
end;


function THTTPResults.ContentTypeIsText: boolean;
begin
  result := (zpos('text/', ContentType) = 0)
         or (zpos('urlencoded', ContentType) >=0);
end;

end.
