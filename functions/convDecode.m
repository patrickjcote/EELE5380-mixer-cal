function [dataBits] = convDecode(llrs,rateNdx)
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

%% Build Trelllis
trellis = poly2trellis(7,[171 133]);
tbl = 32; % traceback length
%% Load Puncture Pattern
switch rateNdx
    case 3
        puncture_pattern = [1 1 1 0 0 1 1 1 1 0 0 1 1 1 1 0 0 1];
        dataBits = vitdec(llrs,trellis,tbl,'term','unquant',puncture_pattern);
    case 2
        puncture_pattern = [1 1 1 0 1 1 1 0 1 1 1 0];
        dataBits = vitdec(llrs,trellis,tbl,'term','unquant',puncture_pattern);
    case 4
        puncture_pattern = [1 1 1 0 0 1 1 0 0 1];
        dataBits = vitdec(llrs,trellis,tbl,'term','unquant',puncture_pattern);
    otherwise
        dataBits = vitdec(llrs,trellis,tbl,'term','unquant');
end

end

