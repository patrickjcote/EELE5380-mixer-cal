function [encBlock] = convEncode(dataBlock,rate)

%%
% rates  [ 1/2;
%             2/3;
%             3/4;
%             5/6;];

%% Load Puncture Pattern
switch rate
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

