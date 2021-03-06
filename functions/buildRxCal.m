function [] = buildRxCal(fb,LSB_FLAG,filtType,instrumentType,instrumentAddress)
%% Build Rx Single Tone LSB/USB
%	This function builds baseband sine and cosine waves to be played
%	out of the I and Q channels of the AWG. The signals are predistorted
%	using the Tx calibration matrix such that when upconverted
%	a perfect, single sideband will be seen in the RF spectrum
%
% INPUTS:
%       fb                  Baseband Frequency [Hz]
%       LSB                 RF Sideband to build Flag, 1->Lower, 0->Upper
%       chnlFilt            Channel Filter (off,Normal,Step)->(0,1,2)
%       instrumentType      VISA Instrument Type
%                           1       - NI
%                           2       - Agilent
%                           'xxxx'  - User Specified
%                           Default - KEYSIGHT
%       intrumentAddress    VISA Instrument Address
%
%

%% Instrument Type
% Default to Keysight 33500 awg
if ~exist('instrumentType','var')
    % Default instrument type is KEYSIGHT
    instrumentType = 'KEYSIGHT';
end
if ~exist('instrumentAddress','var')
    % Default addresss
    instrumentAddress = 'USB0::0x0957::0x2C07::MY52801516::0::INSTR';
end

% Set Instrument type if variable is numeric
if isnumeric(instrumentType)
    switch instrumentType
        case 1
            instrumentType = 'NI';
        case 2
            instrumentType = 'Agilent';
        otherwise
            instrumentType = 'KEYSIGHT';
    end
end

%%
% If the Sideband selector flag LSB is not set, prompt for one
if ~exist('LSB_FLAG','var')
    answer = questdlg('Which RF Sideband? ', ...
        'RF Tone Build', ...
        'LSB','USB','USB');
    % Handle response
    switch answer
        case 'LSB'
            LSB_FLAG = 1;
        case 'USB'
            LSB_FLAG = 0;
    end
end

% If Baseband Freq variable fb is not set, prompt
if ~exist('fb','var')
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
end

%% Build I and Q
% Parameters
spc = 50;       % Samples per cycle
Fsamp = spc*fb; % Wavegen Sample Rate
% Built time Vector
t = (0:1/Fsamp:0.5)';
% Build Signal
if LSB_FLAG == 1
    disp('Building Lower Sideband Files...');
    Itx = cos(2*pi*fb*t);
    Qtx = sin(2*pi*fb*t);
else
    disp('Building Upper Sideband Files...');
    Qtx = cos(2*pi*fb*t);
    Itx = sin(2*pi*fb*t);
end

%% Apply Transmitter Correction
load('Calibration Files\txMixerCoefs.mat');     % Mixer calibration parameters
txCor = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
Itxp = txCor(1,:)';
Qtxp = txCor(2,:)';

%% Try to Write Files To ARB
Vpp = 1;    % ARB Output Peak-Peak Voltage
try
    WRITE_TO_DISK = 0;
	sendARB([Itxp, Qtxp],Vpp,Fsamp,filtType,instrumentType,instrumentAddress);
catch
    warning('Failed sending signals to the AWG...');
    WRITE_TO_DISK = 1;
end


%% Write to Thumbdrive
if WRITE_TO_DISK
    
        questdlg({'The Arbitrary Waveform Generator was not detected.', ...
        'so the waveform files (ARBs) are being built locally.',''...
        'Insert a storage device to save .ARB files','',''}, ...
        'Insert Storage Device', ...
        'Ok','Ok');

    dirpath = uigetdir('ARB Files','Select Save Location for Rx Cal ARB Files');
    if ~dirpath
        error('Build Rx Calibration Files Operation Cancled by User');
    end
    if LSB_FLAG
        fnameI = [dirpath,'\LSB_I_cald'];
        fnameQ = [dirpath,'\LSB_Q_cald'];
    else
        fnameI = [dirpath,'\USB_I_cald'];
        fnameQ = [dirpath,'\USB_Q_cald'];
    end
    
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    writeArbFile(fnameQ,Qtxp,Fsamp);
    disp('Rx Calibration ARB build complete...');
    t = length(Itxp)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
end

end

