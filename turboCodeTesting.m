

clear;clc;
%% Encode
blockLen = (6144-12)/3
M = 32;

dataBlock = randi([0 1], blockLen,1);
% Load Encoder objects
hTEnc = comm.TurboEncoder('InterleaverIndicesSource','Input port');
% Build Interleave Indices
rng(654631);    % Interleave randomperm seed
intrlvNdx = randperm(blockLen);
% Encode Data
encBlock = hTEnc(dataBlock,intrlvNdx);

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
demodSignal = qamdemod(rxSig,M,'OutputType','llr','UnitAveragePower',true,'NoiseVariance',noiseVar);
decodeSignal = demodSignal(1:end-padBits);
hTDec = comm.TurboDecoder('InterleaverIndicesSource','Input port','NumIterations',4);
rxBits = hTDec(-decodeSignal,intrlvNdx);

BER = sum(rxBits ~= dataBlock)/length(dataBlock)