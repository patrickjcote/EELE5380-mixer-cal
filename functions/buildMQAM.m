function [] = buildMQAM(txObj,filtType,AWGVisaType,AWGVisaAddress)
%% buildMQAM.m
%
% Build M-QAM signal with supplied data.
% Attempts to send to Agilent Aribitrary Waveform Generator.
% If no device is found, .ARB files will be saved to disk.
%
% INPUTS
%       txObj.Fsym      Symbol Rate
%       txObj.Nsyms 	Frame Length in Symbols
%       txObj.data      Transmit Data Bits
%       txObj.txCal     Apply Transmit Calibration Flag
%       txObj.M         Modulation Order
%       txObj.preM      Preamble m-seq order
%       txObj.preTaps   Preamble m-seq taps
%       filtType        AWG channel filter type (0-off,1-normal,2-step)
%       AWGVisaType     VISA Instrument Type
%                           1       - NI
%                           2       - Agilent
%                           'xxxx'  - User Specified
%                           Default - KEYSIGHT
%       AWGVisaAddress  VISA Instrument Address
%
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

%% Parse Transmit Object (txObj)
try
    M = txObj.M;
    Fsym = txObj.Fsym;
    FECtype = txObj.FEC;
    rate = txObj.rate;
    blockLen = txObj.blockLen;
    rngSeed = txObj.rng;
    TX_CAL = txObj.txCal;
    preambLen = txObj.preambLen;
catch
    error('Tx Object not properly initialized.');
end

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

sps = 50;           % Samples per Symbol        [Samp/sym]


%% Build Data
try
    [encBits, ~] = buildencBlock(blockLen,FECtype,rate,rngSeed);
catch ME
    warning('Error Running buildencBlock');
    warning(ME.message);
    return
end

%% Build BPSK Preamble and Modulated Data Block
% Load Preamble Length, Set M-seq order and taps
switch preambLen
    case 256
        preM = 8;
        preTaps = [8, 6, 5, 4];
    case 512
        preM = 9;
        preTaps = [9, 8, 6, 5];
    case 1024
        preM = 10;
        preTaps = [10, 9, 7, 6];
    case 2048
        preM = 11;
        preTaps = [11, 10, 9, 7];
    otherwise
        preM = 10;
        preTaps = [10, 9, 7, 6];
end

preamble = ([mSeq(preM,preTaps);1]*2-1);    % Preamble M-sequence

preamble = preamble*exp(1i*pi/4);           % Rotate Preamble

% Add padding if necessary to fill constellations
if(mod(length(encBits),log2(M)))
    padBits = log2(M)-mod(length(encBits),log2(M))
else
    padBits = 0
end

txBits = [encBits; randi([0 1], padBits,1)];

dataBlock  = qammod(txBits,M,'InputType','bit','UnitAveragePower',true);
txBlock = [preamble;dataBlock];

%% Build Output
Qtx = rectpulse(imag(txBlock),sps);
Itx = rectpulse(real(txBlock),sps);

% Apply Transmitter Calibration Correction
if TX_CAL
    load('Calibration Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCorrected = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itx = txCorrected(1,:)';
    Qtx = txCorrected(2,:)';
    fnameCal = 'cald';
else
    fnameCal = 'uncal';
end

%% Check For Simulation Mode Flag

if isempty(txObj.SIM_MODE)
    SIM_MODE = 0;
else
    SIM_MODE = txObj.SIM_MODE;
end

if SIM_MODE
    % If simulation mode, save waveforms as .MAT file
    dirpath = uigetdir('Signal Files','Select Save Location for M-QAM Tx Simulation File');
    if ~dirpath
        error('Build M-QAM Files Operation Cancled by User');
    end
    N = round(length(Itx)/4);
    
    Irx = [awgn(zeros(N,1),10);Itx;Itx];
    Qrx = [awgn(zeros(N,1),10);Qtx;Qtx];
    tq = (0:length(Irx)-1)'/(sps*Fsym);
    
    if strcmp(FECtype,'None')
        rate = 6;
        FECtype = 'Uncoded';
    end
    rateVec = {'0.50','0.66','0.75','0.83','0.33','1'};
    fileName = [dirpath,'\',num2str(M),'Q_',FECtype,'_r',rateVec{rate},'_',num2str(blockLen),'.mat'];
    save(fileName,'Irx','Qrx','tq');
    
    return
end

%% Try to Write Files To ARB
Fsamp = sps*Fsym; % Wavegen Sample Rate
Vpp = 1;    % ARB Output Peak-Peak Voltage
try
    WRITE_TO_DISK = 0;
    sendARB([Itx, Qtx], Vpp, Fsamp, filtType, AWGVisaType, AWGVisaAddress);
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
    
    dirpath = uigetdir('ARB Files','Select Save Location for M-QAM Tx ARB Files');
    if ~dirpath
        error('Build M-QAM Tx Files Operation Cancled by User');
    end
    
    % Build AWG Files
    writeArbFile([dirpath,'\',num2str(M),'Q_i_',fnameCal],Itx,Fsamp);
    writeArbFile([dirpath,'\',num2str(M),'Q_q_',fnameCal],Qtx,Fsamp);
    disp('ARB build complete...');
    t = length(Itx)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
end

end

