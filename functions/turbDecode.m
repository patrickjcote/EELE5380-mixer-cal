function [dataBits] = turbDecode(llrs,blockLen,numIts,rateNdx,llrVal)
%% turbDecode.m
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

%% Load Puncture Pattern
if exist('rateNdx','var')
 
    if ~exist('llrVal','var')
        llrVal = 0;
    end
    
    switch rateNdx
        case 1
            disp('1/2 rate puncture');
            punctPattern = [1 1 0  1 0 1];
        case 2
            disp('2/3 rate puncture');
            % 1/3 -> 2/3 rate
            punctPattern = [1 1 0  1 0 0  1 0 0  1 0 1];
        case 3
            disp('3/4 rate puncture')
            punctPattern = [1 1 0  1 0 0  1 0 0   1 0 1  1 0 0  1 0 0   1 0 0  1 1 0  1 0 0 ];
        case 4
            disp('5/6 rate puncture');
            punctPattern = [1 1 0  1 0 0  1 0 0  1 0 0  1 0 0];
        otherwise
            punctPattern = [1];
            disp('Rate 1/3. No puncture.');     
    end
    
    llrs = [puncture(llrs(1:end-12),punctPattern,llrVal);llrs(end-11:end)];

end


%%
rng(6541);    % Interleave randomperm seed
intrlvNdx = randperm(blockLen);
hTDec = comm.TurboDecoder('InterleaverIndicesSource','Input port','NumIterations',numIts);
dataBits = hTDec(-llrs,intrlvNdx);

end

