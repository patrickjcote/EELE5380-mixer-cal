%% Build Rx Single Tone LSB/USB
% Parameters
spc = 50;           % Samples per cycle
fprintf('\n\n');
disp('------ Build Rx Calibration AWG Files --------');
disp('');
disp('This script builds baseband sine and cosine waves to be played');
disp('out of the I and Q channels of the AWG. The signals are predistorted');
disp('using the Tx calibration matrix such that when upconverted')
disp('a perfect, single sideband will be seen in the RF spectrum');
fprintf('\n');

%%
questdlg({'Insert AWG USB...'}, ...
    'Insert Storage Device', ...
    'Ok','Ok');
dirpath = uigetdir('ARB Files','Select Save Location for Rx Cal ARB Files');
if ~dirpath
    dirpath = pwd;
end
%%
% Sideband
answer = questdlg('Which RF Sideband? ', ...
    'RF Tone Build', ...
    'LSB','USB','Both','Both');
% Handle response
switch answer
    case 'LSB'
        LSB = 1;
    case 'USB'
        LSB = 0;
    case 'Both'
        LSB = 2;
end

% Baseband Freq
prompt = {'Enter Baseband Tone Frequency in Hz:'};
title = 'Input';
dims = [1 40];
definput = {'1000'};
answer = inputdlg(prompt,title,dims,definput);

if isempty(answer)
    fb = 1e3;
else
    fb = str2num(answer{1});
end

if isempty(fb)
    fb = 1e3;       % Symbol Rate
end
fprintf('\nBaseband Frequency set to: %d Hz\n\n',fb);

% Build I and Q
Fsamp = spc*fb; % Wavegen Sample Rate
t = (0:1/Fsamp:0.5)';
if LSB == 1
    disp('Building Lower Sideband Files...');
    Itx = cos(2*pi*fb*t);
    Qtx = sin(2*pi*fb*t);
    fnameI = [dirpath,'\LSB_I_cald'];
    fnameQ = [dirpath,'\LSB_Q_cald'];
    
    % Apply Correction
    load('functions\Parameter Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCor = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itxp = txCor(1,:)';
    Qtxp = txCor(2,:)';
    
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    writeArbFile(fnameQ,Qtxp,Fsamp);
    disp('LSB Rx Calibration ARB build complete...');
    t = length(Itxp)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
    
    
elseif LSB == 0
    disp('Building Upper Sideband Files...');
    Qtx = cos(2*pi*fb*t);
    Itx = sin(2*pi*fb*t);
    fnameI = [dirpath,'\USB_I_cald'];
    fnameQ = [dirpath,'\USB_Q_cald'];
    
    % Apply Correction
    load('functions\Parameter Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCor = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itxp = txCor(1,:)';
    Qtxp = txCor(2,:)';
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    writeArbFile(fnameQ,Qtxp,Fsamp);
    disp('USB Rx Calibration ARB build complete...');
    t = length(Itxp)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
else
    disp('Building Lower Sideband Files...');
    Itx = cos(2*pi*fb*t);
    Qtx = sin(2*pi*fb*t);
    fnameI = [dirpath,'\LSB_I_cald'];
    fnameQ = [dirpath,'\LSB_Q_cald'];
    
    % Apply Correction
    load('functions\Parameter Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCor = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itxp = txCor(1,:)';
    Qtxp = txCor(2,:)';
    
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    writeArbFile(fnameQ,Qtxp,Fsamp);
    disp('LSB Rx Calibration ARB build complete...');
    
    disp('Building Upper Sideband Files...');
    Qtx = cos(2*pi*fb*t);
    Itx = sin(2*pi*fb*t);
    fnameI = [dirpath,'\USB_I_cald'];
    fnameQ = [dirpath,'\USB_Q_cald'];
    
    % Apply Correction
    load('functions\Parameter Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCor = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itxp = txCor(1,:)';
    Qtxp = txCor(2,:)';
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    writeArbFile(fnameQ,Qtxp,Fsamp);
    disp('USB Rx Calibration ARB build complete...');
    t = length(Itxp)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
end


