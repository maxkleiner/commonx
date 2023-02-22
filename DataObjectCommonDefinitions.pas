unit DataObjectCommonDefinitions;

interface

const
  CKEY_NEW_ACCOUNT = 0;
  CKEY_NEW_USER = 1;
  CKEY_NEW_MAIL = 8;
  CKEY_NEW_PAYMENT = 9;

  CKEY_NEW_PROCESS = 777;
  CKEY_NEW_HIT = 888;

procedure DefineDataObjects(sender: TOBject);

implementation

uses
  DataObjectFactory, queryobject, SystemObjects,
  AsyncObjects;

procedure DefineDataObjects(sender: TOBject);
begin
  DOCF.RegisterDataObjectClass(TdoQuery, 1);
//DOCF.RegisterDataObjectClass(TdoQueryMap, $0998);
  DOCF.RegisterDataObjectClass(TdoUser,           1, 'select * from user where userid=~~0~~');
  DOCF.RegisterDataObjectClass(TdoRole,           1, 'select * from role where rolid=~~0~~');
  DOCF.RegisterDataObjectClass(TdoSession,        1, 'select * from session where sessionid=~~0~~');
  DOCF.RegisterDataObjectClass(TdoMail,             1);
  DOCF.RegisterDataObjectClass(TdoSessionVar,       2);
  DOCF.RegisterDataObjectClass(TdoSessionVars,      1);


end;

end.
