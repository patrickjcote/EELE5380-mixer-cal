function [dataBits] = ldpcDecode(llrs,blockLen,rate,max_itrs)

% Sm.blockLen = 1944;    % Total Block Length        [648,1296,1944]
% Sm.rate = 1/2;         % Code rate                 [1/2,2/3,3/4,5/6]
if ~exist('max_itrs','var')
    max_itrs = 20;
end

rateVec = [ 1/2;
            2/3;
            3/4;
            5/6;];

ldpc_code = LDPCCode(0, 0);     % LDPC object
ldpc_code.load_wifi_ldpc(blockLen, rateVec(rate));
[decoded_codeword, ~] = ldpc_code.decode_llr(llrs, max_itrs, 0);

% Isolate information bits
dataBits = decoded_codeword(1:ldpc_code.K);

end

