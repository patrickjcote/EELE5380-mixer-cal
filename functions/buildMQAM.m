function [] = buildMQAM(M,Fsym,N_syms,rng_seed,TX_CAL,filtType,instrumentType,instrumentAddress)
% buildMQAM.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems
% Build ARB files for M-QAM system with random data and Tx calibration

%% Instrument Type
% Default to Keysight 33500 awg
if ~exist('instrumentType','var')
    % Default instrument type is KEYSIGHT
    instrumentType = 'KEYSIGHT';
end
if ~exist('intrumentAddress','var')
    % Default addresss
    intrumentAddress = 'USB0::0x0957::0x2C07::MY52801516::0::INSTR';
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


sps = 50;           % Samples per Symbol        [Samp/sym]


%% Build Data Block and Modulate
rng(rng_seed);          % Random Seed
dataBlock = randi([0 1],log2(M)*N_syms,1);
modBlock  = qammod(dataBlock,M,'gray','InputType','bit','UnitAveragePower',true);

%% Build Output
Qtx = rectpulse(imag(modBlock),sps);
Itx = rectpulse(real(modBlock),sps);

% Apply Transmitter Calibration Correction
if TX_CAL
    load('Calibration Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCorrected = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itx = txCorrected(1,:)';
    Qtx = txCorrected(2,:)';
    fname = 'cald';
else
    fname = 'uncal';
end

%% Try to Write Files To ARB
Fsamp = sps*Fsym; % Wavegen Sample Rate
Vpp = 1;    % ARB Output Peak-Peak Voltage
try
    WRITE_TO_DISK = 0;
	sendARB([Itx, Qtx], Vpp, Fsamp, filtType, instrumentType, instrumentAddress);
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

    dirpath = uigetdir('ARB Files','Select Save Location for ARB Files');
    if ~dirpath
        error('Build M-QAM Tx Files Operation Cancled by User');
    end
    
    dirpath = uigetdir('ARB Files','Select Save Location for M-QAM Tx ARB Files');
if ~dirpath
    dirpath = pwd;
end

% Build AWG Files
writeArbFile([dirpath,'\',num2str(M),'Q_i_',fname],Itx,Fsamp);
writeArbFile([dirpath,'\',num2str(M),'Q_q_',fname],Qtx,Fsamp);
disp('ARB build complete...');
t = length(Itx)/Fsamp;
fprintf('Frame Length: %.3f seconds\n',t)
end




















end

