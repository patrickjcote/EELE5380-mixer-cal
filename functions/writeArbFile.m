function []  = writeArbFile( fileName, x, fs )
%% writeArbFile.m
% Function to generate an .arb file for the Agilent 33500B
% arbitrary waveform generator
%
%   INPUTS:
%       fileName        Name of file to be written (overwrites)
%       x               Arbitrary signal
%       fs              Sample rate of signal
%
%   2018 - Montana Tech - Patrick Cote

%% Error Checking
if length(x)>1e6
    error('Max number of data points is 1e6');
end
if fs>1e9
    error('Max sample rate is 1GSa/s');
end

%% File Write

% Open file in write mode
fileID = fopen([fileName,'.arb'],'w');
% Write header
fprintf(fileID,'Copyright:Agilent Technologies, 2010\n');
fprintf(fileID,'File Format:1.10\n');
fprintf(fileID,'Channel Count:1\n');
fprintf(fileID,'Sample Rate:%d\n',fs);
fprintf(fileID,'High Level:%f\n', max(x)/2);
fprintf(fileID,'Low Level:%f\n', min(x)/2);
fprintf(fileID,'Data Type:"short"\n');
fprintf(fileID,'Data Points:%d\n',length(x));
fprintf(fileID,'Data:\n');

% Make sure data is a column
if ~iscolumn(x)
    x = x';
end

x = x/sqrt(max(x.^2));
x = round(32767*x);

% Write signal
fprintf(fileID,'%d\n',x);

% Close file
fclose(fileID);
end

