unit neuron;

//Proposed Designs
//(1) Levenstein of Two Phrases  x   \
//(2) Length of Smallest Phrase  x   - Are these words similar?
//(3) Length of Longest Phrase   x   /


interface

uses
  betterobject, stringx, sharedobject, typex, systemx, threading, sysutils, debug;

const
  WIN_ACCELERATION = 2.0;
  MIN_DESCENT_VELOCITY = 0.00000001;
type
  TWeightAndBias = record
    w: double;
    b: double;
  end;
  TResultClassification = record
    classlabel: string;
    value: double;
  end;

  TPerceptron = record
  public
    w: double;//<---Perceived here
    input: double;
    descentdir: double;//1 or -1
    descentvelocity: double;//1.0---0.0000000000000001
    testing: boolean;
    prevdesc: double;
    procedure Move(dir: double);
    procedure Reverse;
    procedure Reset;
    function Axon: double;
    procedure TestDescent(lr: double);
    procedure RevertDescent;
    function Descend(errorDelta: double; winstreak:nativeint): boolean;
  end;
  PPerceptron = ^TPerceptron;

  TNeuralLayer = record
  private
    function GetNeuronCount: nativeint;
    procedure SetNeuronCount(const Value: nativeint);
  public
    neurons: TArray<TPerceptron>;
    bias: double;//<----perceived here
    biasvelocity: double;
    biasdir: double;
    descentidx: nativeint;
    testing: boolean;
    procedure Move(dir: double);
    procedure Reverse;
    procedure Reset;
    function Descend(errorDelta: double; winstreak:nativeint): boolean;
    procedure CommitDescent;
    function TestingDescent: boolean;

    property NeuronCount: nativeint read GetNeuronCount write SetNeuronCount;
  end;

  TNeuralNetwork = record
    layers: TArray<TNeuralLayer>;
    expectations: TArray<TResultClassification>;

  end;

  TNeuralProcessor = class(TSharedObject)
  private
    function GetTotalLoss: double;
    function GetLossRespectingWeight(nidx: nativeint): double;
    //iterate input
  protected
    perceptronindex: nativeint;
    procedure ResetSample;
    function NextPerceptron: PPerceptron;//an easy way to iterate through inputs during setup
    function NextOutput: PPerceptron;    //an easy way to iterate through outputs when finished

    procedure DoSetupSample(idx: int64);virtual;///<<<----OVERRIDE ME!
    procedure DoConfigure;virtual;              ///<<<----OVERRIDE ME!
    procedure SampleReady(idx: int64);virtual;  ///<<<----OVERRIDE ME!
    function GetSampleCount: int64;virtual;     ///<<<----OVERRIDE ME!
    procedure DoIterationFinished;virtual;      ///<<<----OVERRIDE ME!
    procedure OnComplete;virtual;
  public
    previouserror: double;
    totalerror: double;
    net: TNeuralNetwork;
    onsampleready: TProc<int64>;
    oniterationFinished: TProc<int64>;
    learningrate: double;
    trainingrate: double;
    errorstop: double;
    iteration: int64;
    winstreak:nativeint;

    procedure Reset;
    procedure Setup(inputs,middle,outputs: nativeint;rErrorStop: double; rTrainingRate: double);
    procedure InitialEstimate;
    procedure ProcessSample(idx: int64);
    procedure IterationFinished;
    function GetGradientOf(layer,weight: nativeint): double;
    function Descend: boolean;
    procedure Complete;

    function Iterate: double;
    procedure Process;//<<-------KEY
    procedure Configure;


  end;



implementation

{ TPerceptron }

function TPerceptron.Axon: double;
begin
  result := w*input;
end;

function TPerceptron.Descend(errorDelta: double; winstreak:nativeint): boolean;
begin
  //if not improving then
  if errorDelta >= 0.0 then begin
    //descend slower in the opposite direction
    descentvelocity := descentvelocity / 2.0;
    descentdir := 0.0-descentdir;
  end;

  w := w + (descentdir*descentvelocity);
  if winstreak > 1 then
    descentvelocity := descentvelocity * WIN_ACCELERATION;


  result := descentvelocity >= 0.00000001;
  if not result then
    descentvelocity := 0.00000001;



end;

procedure TPerceptron.Move(dir: double);
begin
  w := w + (Self.descentvelocity*(dir*self.descentdir));
end;

procedure TPerceptron.Reset;
begin
  w := 1.0;
  descentvelocity := 1.0;
  descentdir := 1.0;

end;

procedure TPerceptron.Reverse;
begin
  descentdir := 0.0-descentdir;
  descentvelocity := descentvelocity /2.0;
end;

procedure TPerceptron.RevertDescent;
begin
  if not testing then
    raise Ecritical.create('cannot revert descent because not testing');
  w := w - (descentdir*descentvelocity);
end;

procedure TPerceptron.TestDescent;
begin
  w := w + (descentdir*descentvelocity);
  testing := true;
end;

{ TNeuralProcessor }

procedure TNeuralProcessor.Complete;
begin
  OnComplete;
end;

procedure TNeuralProcessor.Configure;
begin
  DoConfigure;
end;

function TNeuralProcessor.Descend: boolean;
begin
  result := false;
  for var l := 0 to high(net.layers) do begin
    for var n := 0 to net.layers[l].neuroncount-1 do begin
      var lasterr := totalerror;
      if net.layers[l].neurons[n].descentvelocity >= MIN_DESCENT_VELOCITY then begin
        net.layers[l].neurons[n].Move(1.0);
        var nuerror := Iterate;
        if nuerror > lasterr then begin
          net.layers[l].neurons[n].Move(-1.0);
          net.layers[l].neurons[n].reverse;
        end;
//        var grad := GetGradientOf(l,n);
//        if grad < 0.0 then
//          net.layers[l].neurons[n].descentdir := -1.0
//        else
//          net.layers[l].neurons[n].descentdir := 1.0;
//        net.layers[l].neurons[n].move(1.0);
        result := true;
      end;
    end;
    var lasterr := totalerror;
    net.layers[l].Move(1.0);
    var nuerror := Iterate;
    if nuerror > lasterr then begin
      net.layers[l].move(-1.0);
      net.layers[l].reverse;
      totalerror := lasterr;
    end;
  end;
end;

procedure TNeuralProcessor.DoConfigure;
begin
  //
end;

procedure TNeuralProcessor.DoIterationFinished;
begin
//
end;

procedure TNeuralProcessor.DoSetupSample(idx: int64);
begin
  //

end;

function TNeuralProcessor.GetSampleCount: int64;
begin
  result := 0;

end;

procedure TNeuralProcessor.InitialEstimate;
var
  a: Tarray<double>;
begin
  setlength(a,net.layers[0].NeuronCount);
  for var n := 0 to high(a) do
    a[n] := 0;

  if GetSampleCount <=0 then
    raise ECritical.create('no data specified');

  for var idx := 0 to GetSampleCount-1 do begin
    PerceptronIndex := 0;
    DoSetupSample(idx);
    for var n := 0 to high(a) do
      a[n] := a[n] + net.layers[0].neurons[n].input;

  end;

  for var n := 0 to high(a) do begin
    net.layers[0].neurons[n].w := a[n] / GetSampleCount;
  end;


end;

function TNeuralProcessor.Iterate: double;
begin
  totalerror := 0.0;

  for var t:int64 := 0 to GetSampleCount-1 do
    ProcessSample(t);

  result := totalerror;

end;

procedure TNeuralProcessor.IterationFinished;
begin

  if assigned(onIterationFinished) then
    onIterationFinished(iteration);

  DoIterationFinished;
  inc(iteration);


end;

function TNeuralProcessor.NextOutput: PPerceptron;
begin
  result := @net.layers[high(net.layers)].neurons[perceptronindex];
  inc(perceptronindex);
end;

function TNeuralProcessor.NextPerceptron: PPerceptron;
begin
  result := @net.layers[0].neurons[perceptronindex];
  inc(perceptronindex);

end;

procedure TNeuralProcessor.OnComplete;
begin

end;

procedure TNeuralProcessor.Process;
begin
  configure;
  InitialEstimate;
  perceptronindex := 0;
  previouserror := 0.0;
  var errordelta :double := 0.0;
  repeat

    Iterate;
    errordelta := totalerror-previouserror;





    if errordelta <= 0.0 then
      inc(winstreak)
    else
      winstreak := 0;

    if not Descend then //once velocities reach < 0.00000001 descent will return false
      exit;

    iterationfinished;
    previouserror := totalError;
    var s := '';
    for var t := 0 to net.layers[0].NeuronCount-1 do
      s := s + '['+inttostr(t)+']='+floatprecision(net.layers[0].neurons[t].w,8);
    s := s + '[B]='+floatprecision(net.layers[0].bias,8);

    debug.log('error: '+floatprecision(totalerror,8)+ ' '+s);



  until totalerror < errorStop;
  if totalerror < errorStop then
    debug.log('error stop hit '+floattostr(totalerror));




end;

function TNeuralProcessor.GetTotalLoss: double;
begin
  result := 0.0;
  for var t := 0 to net.layers[high(net.layers)].NeuronCount-1 do begin
    var actual := net.layers[high(net.layers)].neurons[t].Axon;
    var expect := net.expectations[t].value;
    var dif := actual-expect;
    result := result + ((dif)*(dif));
  end;
end;

function TNeuralProcessor.GetGradientOf(layer, weight: nativeint): double;
begin
  var err1 := Iterate;
  net.layers[layer].neurons[weight].Move(1.0);
  var err2 := Iterate;
  result := err2-err1;
  net.layers[layer].neurons[weight].Move(-1.0);
end;

function TNeuralProcessor.GetLossRespectingWeight(nidx: nativeint): double;
begin

end;
procedure TNeuralProcessor.ProcessSample(idx: int64);
begin
  perceptronindex := 0;
  ResetSample;
  DoSetupSample(idx);
  for var t := 1 to high(net.layers) do begin
    var prev := t-1;
    for var n := 0 to net.layers[t].neuronCount-1 do begin
      for var pn := 0 to net.layers[prev].NeuronCount-1 do begin
        net.layers[t].neurons[n].input := net.layers[t].neurons[n].input + net.layers[prev].neurons[pn].axon+net.layers[prev].bias
      end;
    end;
  end;

  perceptronindex := 0;

  totalError := totalError+GetTotalLoss;
  SampleReady(idx);





end;

procedure TNeuralProcessor.Reset;
begin
  iteration := 0;
  for var t := 1 to high(net.layers)-1 do begin
    net.layers[t].Reset;
  end;
  net.layers[0].Reset;
  net.layers[high(net.layers)].Reset;

end;

procedure TNeuralProcessor.ResetSample;
begin

  for var t := 0 to high(net.layers) do begin
    for var u := 0 to net.layers[t].NeuronCount-1 do begin
      net.layers[t].neurons[u].input := 0.0;
    end;

  end;


end;

procedure TNeuralProcessor.SampleReady(idx: int64);
begin
  if assigned(onsampleready) then
    onSampleReady(idx);
//
end;

procedure TNeuralProcessor.Setup(inputs, middle, outputs: nativeint; rErrorStop: double; rTrainingRate: double);
begin
  errorstop := rErrorStop;
  trainingrate := rTrainingRate;
  setlength(net.layers, middle + 2);
  net.layers[0].NeuronCount := inputs;
  net.layers[high(net.layers)].NeuronCount := outputs;
  setlength(net.expectations, outputs);
  for var t := 1 to high(net.layers)-1 do begin
    net.layers[t].NeuronCount := inputs+1;
  end;
  Reset;

end;

{ TNeuralLayer }

procedure TNeuralLayer.CommitDescent;
begin
  testing := false;
end;

function TNeuralLayer.Descend(errorDelta: double; winstreak:nativeint): boolean;
begin
//  if errorDelta > 0.0 then
//    for var n := 0 to neuroncount-1 do
//      neurons[n].Rollback(errorDelta);
//
  result := false;

  //treat each dimension as a vector
//      t = Iteration number
//      T = Total iterations
//      n = Total variables  in the domain of f  (also called the dimensionality of x)
//      j = Iterator for variable number, e.g., x_j represents the jth variable
//      𝜂 = Learning rate
//      ∇f(x[t]) = Value of the gradient vector of f at iteration t
//
//Initial t=0
//       x[0] = (4,3)     # This is just a randomly chosen point
//At t = 1
//       x[1] = x[0] – 𝜂∇f(x[0])
//       x[1] = (4,3) – 0.1*(8,12)
//       x[1] = (3.2,1.8)
//At t=2
//       x[2] = x[1] – 𝜂∇f(x[1])
//       x[2] = (3.2,1.8) – 0.1*(6.4,7.2)
//       x[2] = (2.56,1.08)
// JRN: In a nutshell... treating the previous value as a vecto


  for var n := 0 to neuroncount-1 do
    result := result or neurons[n].Descend(errorDelta, winstreak);

  if not result then begin
    if errorDelta >= 0.0 then begin
      biasdir := 0.000000-biasdir;
      biasvelocity := biasvelocity / 2;
    end;

    bias := bias+(biasvelocity*biasdir);
    result := biasvelocity >= 0.00000001;
    if not result then
      biasvelocity := 0.00000001;

    if winstreak > 1 then
      biasvelocity := biasvelocity * WIN_ACCELERATION;

  end;

end;

function TNeuralLayer.GetNeuronCount: nativeint;
begin
  result := Length(neurons);
end;

procedure TNeuralLayer.Move(dir: double);
begin
  bias := biasvelocity*(biasdir*dir);

end;

procedure TNeuralLayer.Reset;
begin
  bias := 0.0;
  biasdir := 1.0;
  biasvelocity := 10000.0;
  for var t := 0 to neuroncount-1 do
    neurons[t].Reset;
end;

procedure TNeuralLayer.Reverse;
begin
  biasdir := 0.0-biasdir;
  biasvelocity := biasvelocity /2.0;
end;

procedure TNeuralLayer.SetNeuronCount(const Value: nativeint);
begin
  setlength(neurons,value);
end;

function TNeuralLayer.TestingDescent: boolean;
begin
  for var t := 0 to high(neurons) do
    if neurons[t].testing then exit(true);
  exit(false);

end;

end.
