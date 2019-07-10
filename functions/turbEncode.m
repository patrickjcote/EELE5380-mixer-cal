function [encBlock,dataBits] = turbEncode(dataLen,rng_seed)
%% convDecode.m
%
%	This function convolutionally encodes a the supplied dataBlock. 
%   The decode function assumes the original data bits are terminated 
%   with enough 0's to fully flush the encoder.
%
%   Constraint length 7 encoder with Octal Trellis 171 and 133
%   
%   Total block length after encoding must result in an integer multiple of
%   puncture pattern selected by rate.
%
% INPUTS:
%       dataBlock       Block of data bits 
%       rateNdx         Rate selector index:(1-4)->[ 1/2, 2/3, 3/4, 5/6]

% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

%%
rng(rng_seed);          % Random Seed
dataBits = randi([0 1],dataLen,1);
% Load Encoder objects
hTEnc = comm.TurboEncoder('InterleaverIndicesSource','Input port');
% Build Interleave Indices
rng(6541);    % Interleave randomperm seed
intrlvNdx = randperm(dataLen);
% Encode Data
encBlock = hTEnc(dataBits,intrlvNdx);

end

