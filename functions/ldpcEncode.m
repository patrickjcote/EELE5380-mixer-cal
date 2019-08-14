function [encBlock] = ldpcEncode(dataBits,blockLen,r)
%% ldpcDecode.m
%
%	This function builds an LDPC encoded signal. 
%
% INPUTS:
%       blockLen        Total Block Length        [648,1296,1944]
%       rateNdx         Rate selector index:  (1-4)->[ 1/2, 2/3, 3/4, 5/6]
%       RNG_SEED        Random Number Generator Seed
% OUTPUS:
%       dataBits        Uncoded bits
%       encBlock        Encoded bits
%
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

% Encode
ldpc_code = LDPCCode(0, 0);                     % Init LDPC object
ldpc_code.load_wifi_ldpc(blockLen, r);       % Set ldpc parameters
encBlock = ldpc_code.encode_bits(dataBits);    % Encode data bits

end

