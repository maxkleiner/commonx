unit PacketAbstract;

interface

uses
  betterobject, networkbuffer, typex;

const
  PACKET_PLATFORM_OPTION_SUPPORTS_64BIT_PACKETS = 2;
  PACKET_PLATFORM_OPTION_SUPPORTS_COMPRESSION = 1;
  ENCRYPT_VERBATIM = 0;//PACKET_PLATFORM_OPTION_SUPPORTS_COMPRESSION xor 1;
  ENCRYPT_RLE = 1;//PACKET_PLATFORM_OPTION_SUPPORTS_COMPRESSION;

  TYPICAL_PACKET_SIZE = 65536;
  PACKET_INDEX_RESPONSE_TYPE = 0;
  PACKET_INDEX_SESSION = 1;
  PACKET_INDEX_RESULT = 2;
  PACKET_INDEX_ERROR_CODE = 3;
  PACKET_INDEX_MESSAGE = 4;
  PACKET_INDEX_RESULT_DETAILS = 5;

type
  TPacketOrigin = (poClient, poServer);
  TRDTPDataType = byte;

  TRDTPPacketAbstract = class(TBetterObject)
  private
    FOrigin: TPacketOrigin;
    FPlatformOptions: cardinal;

  protected
    FBuffer: TNetworkBuffer;
    FEncrypted: boolean;
    FCRCUpdated: boolean;
    function GetEncryptedBuffer: TNetworkBuffer;inline;
    function GetDecryptedBuffer: TNetworkBuffer;inline;
    function GetEncryption: byte;virtual;abstract;
    procedure SetEncryption(i:byte);virtual;abstract;
    function GetIsResponse: boolean;
    function GetDataCount: int64;virtual;abstract;
    function GetResponseType: smallint;virtual;abstract;
    function GetResult: boolean;virtual;abstract;
    function GetErrorCode: smallint;virtual;abstract;
    function GetMessage: string;virtual;abstract;
    //Property-related functions
    function GetMarker: integer;virtual;abstract;
    procedure SetMarker(l: integer);virtual;abstract;
    function GetPackedLength: int64;virtual;abstract;
    function GetUnPackedLength: int64;virtual;abstract;
    function GetPacketType: byte;virtual;abstract;
    procedure SetPacketType(l: byte);virtual;abstract;
    function GetDataType(idx: int64): TRDTPDataType;virtual;abstract;
    function GetNextDataType: TRDTPDataType;virtual;abstract;
    function GetSessionID: int64;virtual;abstract;
    function GetCRC: cardinal;virtual;abstract;
    function GetData(idx: int64): variant;virtual;abstract;



  public
    procedure Initialize;virtual;abstract;
    procedure Clear;virtual;abstract;

    constructor Create; override;
    property PlatformOptions: cardinal read FPlatformOptions write FPlatformOptions;
    property Origin: TPacketOrigin read FOrigin write FOrigin;
    //Packet definition functions
    property DecryptedBuffer: TNetworkBuffer read GetDecryptedBuffer;
    property EncryptedBuffer: TNetworkBuffer read GetEncryptedBuffer;
    property Encryption: byte read GetEncryption write SetEncryption;
      //The encryption method as reported by packet header
    property Encrypted: boolean read FEncrypted;
    procedure Encrypt;virtual;abstract;
    procedure Decrypt;virtual;abstract;

    //Additional Packet Attributes
    property IsResponse: boolean read GetIsResponse;



    //These definitions are standard for response packets.
    //They cannot be accessed unless the packet was recieved from the network.
    property ResponseType: smallint read GetResponseType;
    property Result: boolean read GetResult;
    property SessionID: int64 read GetSessionID;
    property ErrorCode: smallint read GetErrorCode;
    property Message: string read GetMessage;

      //This is the buffer in which the raw packet data is stored;
    property Marker: integer read GetMarker write SetMarker;
      //The marker should always be the same
    property UnPackedLength: int64 read GetUnPackedLength;
    property PackedLength: int64 read GetPackedLength;
      //The length of the packet... as reported by the packet header.
      //When building packets, the packet header is automatically updated.
    property PacketType: byte read GetPacketType write SetPacketType;
      //Packet type... almost always 1... will default to 1
    property CRC: cardinal read GetCRC;
      //The CRC Reported by packet header
    property CRCUpdated: boolean read FCRCUpdated;
      //Tells whether or not the Packet data is encrypted currently
    property DataCount: int64 read GetDataCount;
      //The number of items in the UserData porton of the packet.
    property Data[idx: int64]: variant read GetData;  default;
      //An index of shorts, strings, longs, and byte types included in the
      //UserData portion of the packet.
    property DataType[idx: int64]: TRDTPDataType read GetDataType;


    //Packet Buidling Rountines
    procedure Addlong(l: integer);virtual;abstract;
    procedure AddShort(i: smallint);virtual;abstract;
    procedure AddDouble(d: double);virtual;abstract;
    procedure AddNull;virtual;abstract;
    procedure AddBoolean(b: boolean);virtual;abstract;
    procedure AddString(s: string);virtual;abstract;
    procedure AddDateTime(d: TDateTime);virtual;abstract;
    procedure AddBytes(pc: PByte; iLength: int64);virtual;abstract;
    procedure AddObject(iObjectType, iKeys, iFields, iAssociates, iObjects: int64);virtual;abstract;
    procedure AddShortObject(iObjectType, iKeys, iFields, iAssociates, iObjects: int64);virtual;abstract;
    procedure AddLongObject(iObjectType, iKeys, iFields, iAssociates, iObjects: int64);virtual;abstract;
    procedure UpdateLongObject(iPos: int64; iObjectType, iKeys, iFields, iAssociates, iObjects: int64);virtual;abstract;
    procedure AddLongLong(int: int64);virtual;abstract;
    procedure AddFlexInt(int: int64);virtual;abstract;
    procedure AddInt(i: int64);virtual;abstract;
    function AddVariant(v: variant): boolean;virtual;abstract;

    //Sequetial reading function
    procedure SeqDecodeObjectHeader(OUT iObjectType, iKeys,
        iFields, iAssociates, iObjects: cardinal);virtual;abstract;

    function SeqRead: variant;virtual;abstract;
    procedure SeqSeek(iPos: int64);virtual;abstract;
    function SeqReadBytes(out iLength: int64): PByte;overload;virtual;abstract;
    function SeqReadBytes: TDynByteArray;overload;virtual;abstract;

    function Eof: boolean;virtual;abstract;


    function GetDebugMessage: string;virtual;abstract;

    procedure AssignBuffer(p: pbyte; l: ni);

  end;


implementation

{ TRDTPPacketAbstract }

constructor TRDTPPacketAbstract.Create;
begin
  inherited;
  FOrigin := poClient;
  //Allocate the maximum possible size for the packet in memory
  FBuffer := TNetworkBuffer.create(TYPICAL_PACKET_SIZE);
end;


//---------------------------------------------------------------------------
function TRDTPPacketAbstract.GetEncryptedBuffer: TNetworkBuffer;
begin
  if not Encrypted then Encrypt;
  result := Fbuffer;

end;
function TRDTPPacketAbstract.GetIsResponse: boolean;
begin
  if self = nil then
    raise ECritical.create('self is nil');
  result := Origin = poServer;
end;

//---------------------------------------------------------------------------
function TRDTPPacketAbstract.GetDecryptedBuffer: TNetworkBuffer;
begin
  if Encrypted then Decrypt;
  result := Fbuffer;

end;

procedure TRDTPPacketAbstract.AssignBuffer(p: pbyte; l: ni);
begin
  FEncrypted := true;
  FBuffer.AssignBuffer(p,l);
end;



end.
