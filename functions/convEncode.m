function [encBlock] = convEncode(dataBlock,rateNdx)
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

%% Load Puncture Pattern
switch rateNdx
    case 3
        disp('3/4 rate puncture')
        puncture_pattern = [1 1 1 0 0 1 1 1 1 0 0 1 1 1 1 0 0 1];
    case 2
        disp('2/3 rate puncture');
        puncture_pattern = [1 1 1 0 1 1 1 0 1 1 1 0];
    case 4
        disp('5/6 rate puncture');
        puncture_pattern = [1 1 1 0 0 1 1 0 0 1];
    otherwise
        disp('1/2 rate, no puncture');
        puncture_pattern = [];
end

%% Build Trelllis
trellis = poly2trellis(7,[171 133]);

%% Encode and Puncture
encBlock = convenc(dataBlock,trellis,puncture_pattern);

end

