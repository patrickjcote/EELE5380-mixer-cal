function [dataBits] = ldpcDecode(llrs,blockLen,rateNdx,max_itrs)
%% ldpcDecode.m
%
%	This function decodes an LDPC encoded signal. 
%
% INPUTS:
%       llrs            Soft-decision demodulation LLRs
%       blockLen        Total Block Length        [648,1296,1944]
%       rateNdx         Rate selector index:  (1-4)->[ 1/2, 2/3, 3/4, 5/6]
%       max_itrs        Maximum number of iterations during decode
% OUTPUS:
%       dataBits        Decoded bits
%
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

% Default Max iterations to 20
if ~exist('max_itrs','var')
    max_itrs = 20;
end

% Build Rates Vector
rateVec = [ 1/2; 2/3; 3/4; 5/6];
% Initialize LDPC object
ldpc_code = LDPCCode(0, 0);    
% Set LDPC object block length and coding rate
ldpc_code.load_wifi_ldpc(blockLen, rateVec(rateNdx)); 
% Decoded LLRs
[decoded_codeword, ~] = ldpc_code.decode_llr(llrs, max_itrs, 0);
% Isolate information bits
dataBits = decoded_codeword(1:ldpc_code.K);

end

