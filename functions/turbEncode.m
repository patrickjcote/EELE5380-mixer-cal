function [encBlock] = turbEncode(dataBits,rateNdx)
%% turbEncode.m
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
% Load Encoder objects
hTEnc = comm.TurboEncoder('InterleaverIndicesSource','Input port');
% Build Interleave Indices
rng(6541);    % Interleave randomperm seed
intrlvNdx = randperm(length(dataBits));
% Encode Data
encBits = hTEnc(dataBits,intrlvNdx);

%% Load Puncture Pattern
if exist('rateNdx','var')

    switch rateNdx
        case 1
            disp('1/2 rate puncture');
            punctPattern = [1 1 0 1 0 1];
        case 2
            disp('2/3 rate puncture');
            % 1/3 -> 2/3 rate
            punctPattern = [1 1 0 1 0 0 1 0 1 1 0 0];
        case 3
            disp('3/4 rate puncture')
            punctPattern = [1 1 0  1 0 0  1 0 0    1 0 1  1 0 0  1 0 0];

        case 4
            disp('5/6 rate puncture');
            punctPattern = [1 1 1 0 0 1 1 0 0 1];
        otherwise
            disp('Rate 1/3. No puncture.');
            encBlock = encBits;
            return
    end
    
    encBlock = puncture(encBits,punctPattern);

end

end

