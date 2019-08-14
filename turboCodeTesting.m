

clear;clc;
%% Encode
blockLen = (648-12)/3
M = 32;

dataBlock = randi([0 1], blockLen,1);
% Load Encoder objects
hTEnc = comm.TurboEncoder('InterleaverIndicesSource','Input port');
% Build Interleave Indices
rng(654631);    % Interleave randomperm seed
intrlvNdx = randperm(blockLen);
% Encode Data
encBlock = hTEnc(dataBlock,intrlvNdx);

% 1/3 -> 1/2 rate
puncPattern = [ 1 1 0 1 0 1];
% 1/3 -> 2/3 rate
% puncPattern = [1 1 0 1 0 0 1 0 0 1 0 1];
% 1/3 -> 3/4 rate
% puncPattern = [1 1 0 1 0 0 1 0 0 1 0 1 1 0 0 1 0 0];
% 1/3 -> 5/6 rate
% puncPattern = [1 1 0 1 0 0 1 0 0 1 0 0 1 0 0 1 1 0 1 0 0 1 0 0 1 0 0];
puncPattern = [ 1 1 0 1 0 1];
puncPattern2 = [1 1 1 0 0 1 1 0 0 1]



llrVal = 0;
encBlock = puncture(encBlock,puncPattern);
encBlock = puncture(encBlock,puncPattern2);
r = blockLen/length(encBlock)

if(mod(length(encBlock),log2(M)))
    padBits = log2(M)-mod(length(encBlock),log2(M))
else
    padBits = 0
end
txBlock = [encBlock; randi([0 1], padBits,1)];

SNR = 25;
noiseVar = 10.^(-SNR/10)
if noiseVar<5e-2
	noiseVar = 0.01;
end

modSignal = qammod(txBlock,M,'InputType','bit','UnitAveragePower',true);
rxSig = awgn(modSignal, SNR,'measured');
scatterplot(rxSig)
demodSignal = qamdemod(rxSig,M,'OutputType','llr','UnitAveragePower',true,'NoiseVariance',noiseVar);
decodeSignal = demodSignal(1:end-padBits);

decodeSignal = puncture(decodeSignal,puncPattern2,llrVal/noiseVar);
decodeSignal = puncture(decodeSignal,puncPattern,llrVal/noiseVar);

hTDec = comm.TurboDecoder('InterleaverIndicesSource','Input port','NumIterations',40);
rxBits = hTDec(-decodeSignal',intrlvNdx);

BER = sum(rxBits ~= dataBlock)/length(dataBlock)