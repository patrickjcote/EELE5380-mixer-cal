function [encBlock, dataBits] = ldpcEncode(blockLen,rate,RNG_SEED)

% Sm.blockLen = 1944;    % Total Block Length        [648,1296,1944]
% Sm.rate = 1/2;         % Code rate                 [1/2,2/3,3/4,5/6]


rateVec = [ 1/2;
            2/3;
            3/4;
            5/6;];
        
% TODO: Fix GUI to only allow M = [2,4,16,64] for ldpc

%% Generate Random Data
rng(RNG_SEED);
dataBits = randi([0 1],round(blockLen*(rateVec(rate))),1);

%% Encode
ldpc_code = LDPCCode(0, 0);                     % Init LDPC object
ldpc_code.load_wifi_ldpc(blockLen, rateVec(rate));       % Set ldpc parameters
encBlock = ldpc_code.encode_bits(dataBits);    % Encode data bits

end

