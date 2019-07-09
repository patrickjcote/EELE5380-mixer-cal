


%% Encode
blockLen = 50
M = 1024;

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
end
txBlock = [encBlock; randi([0 1], padBits,1)];

modSignal = qammod(txBlock,M,'gray','InputType','bit','UnitAveragePower',true);
rxSig = awgn(modSignal, 6);
demodSignal = qamdemod(rxSig,M,'gray','OutputType','llr','UnitAveragePower',true);
decodeSignal = demodSignal(1:end-padBits);
hTDec = comm.TurboDecoder('InterleaverIndicesSource','Input port','NumIterations',20);
rxBits = hTDec(-decodeSignal,intrlvNdx);

BER = sum(rxBits ~= dataBlock)/length(dataBlock)