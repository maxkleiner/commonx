unit FileSync;

interface

type
  TFileSyncOption = (optDontRun, optOnlyStartIfServiceRunning, optNoKill, optAlwaysKill,optAlwaysStartAsService, optPassParams);
  TFileSyncOptions = set of TFileSyncOption;


implementation

end.
