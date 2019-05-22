function [] = buildFiltCal(AWGVisaType,AWGVisaAddress)
%% buildFiltCal.m
%
%   Build Impulse and send to AWG for analog filter tuning.
%
% INPUTS:
%       AWGVisaType      VISA Instrument Type
%                           1       - NI
%                           2       - Agilent
%                           'xxxx'  - User Specified
%                           Default - KEYSIGHT
%       AWGVisaAddress    VISA Instrument Address
%
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

%% Hard Coded Parameters
% TODO: Add parameters variable to function arguments
pulse_width = 10e-6;    % Pulse Width                   [s]
duty = 1;               % Percent Duty Cycle            [%]
sps = 10;               % Oversample factor             [n]
Vpp = 5;                % ARB Output Peak-Peak Voltage  [V]
%% Instrument Type
% Default to Keysight 33500 awg
if ~exist('AWGVisaType','var')
    % Default AWGVisa type is KEYSIGHT
    AWGVisaType = 'KEYSIGHT';
end
if ~exist('AWGVisaAddress','var')
    % Default addresss
    AWGVisaAddress = 'USB0::0x0957::0x2C07::MY52801516::0::INSTR';
end

% Set Instrument type if variable is numeric
if isnumeric(AWGVisaType)
    switch AWGVisaType
        case 1
            AWGVisaType = 'NI';
        case 2
            AWGVisaType = 'Agilent';
        otherwise
            AWGVisaType = 'KEYSIGHT';
    end
end

%% Build Pulse
% Calcs
Fsamp = round(sps/pulse_width); % Wavegen Sample Rate
N = pulse_width*Fsamp;          % Samples Per Pulse
% Built pulse Vector
Itx = zeros(N/(duty/100),1);
Itx(N:N+N-1) = ones(N,1);

%% Try to Write Files To ARB
try
    sendARB(Itx,Vpp,Fsamp,0,AWGVisaType,AWGVisaAddress);
    WRITE_TO_DISK = 0;
catch
    warning('Failed sending signal to the AWG...');
    WRITE_TO_DISK = 1;
end

%% If AWG Send Failed, Write to Disk
if WRITE_TO_DISK
    
    questdlg({'The Arbitrary Waveform Generator was not detected.', ...
        'so the waveform files (ARBs) are being built locally.',''...
        'Insert a storage device to save .ARB files','',''}, ...
        'Insert Storage Device', ...
        'Ok','Ok');
    
    dirpath = uigetdir('ARB Files','Select Save Location for Fitler Cal ARB Files');
    if ~dirpath
        error('Build Fitler Calibration Files Operation Cancled by User');
    end
    fnameI = [dirpath,'\filtCalImpulse'];
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    disp('Fitler Calibration ARB build complete...');
    t = length(Itxp)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
end

end

