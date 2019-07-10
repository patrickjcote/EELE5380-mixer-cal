function [dataBits] = turbDecode(llrs,blockLen,numIts)
%% convDecode.m
%
%	This function decodes a convolutionally encoded signal. Assumes the
%	original data bits were terminated with enough 0's to fully flush the
%	encoder.
%
%   Constraint length 7 encoder with Octal Trellis 171 and 133
%
% INPUTS:
%       llrs            Soft-decision demodulation LLRs
%       rateNdx         Rate selector index:  (1-4)->[ 1/2, 2/3, 3/4, 5/6]
% OUTPUTS:
%       dataBits        Decoded bits

% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems


rng(6541);    % Interleave randomperm seed
intrlvNdx = randperm(blockLen);
hTDec = comm.TurboDecoder('InterleaverIndicesSource','Input port','NumIterations',numIts);
dataBits = hTDec(-llrs,intrlvNdx);

end

