function [dataBits] = convDecode(llrs,rate,Nbits)

%%
% rates  [ 1/2;
%             2/3;
%             3/4;
%             5/6;];

%% Build Trelllis
trellis = poly2trellis(7,[171 133]);
tbl = 32; % traceback length
%% Load Puncture Pattern
switch rate
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

