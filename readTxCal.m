% readTxCal.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

%% GUI Test
% If SIM_MODE is not declared this script is not being run from the GUI app
%   so clear the workspace
if ~exist('SIM_MODE','var')
    clear; 
end

%% Check for VISA Address and Type, if none, set defaults
if ~exist('VISAaddr','var')
    disp('Setting default DSO address');
    VISAaddr = 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR'; 
end

if ~exist('VISAtype','var')
    disp('Setting default DSO type');
    VISAtype = 'KEYSIGHT'; 
end

%% Add Functions Path
try
    addpath('functions\');
catch
    warning('Functions Path Not Found.');
end

%% Cal Parameters
% Frequency Parameters
fb = 5e3;           % Baseband Signal frequency         [Symbols/s]
fLO = 100e3;        % Ideal Local Oscillator Freq       [Hz]

% Calibration Sequence Generator Parameters
N = 10;             % Number of shift registers for m seq generation
Itaps = [10 9 5 2]; % Feedback Taps for I seq
Qtaps = [10 9 7 6]; % Feedback Taps for Q seq

% SNR Threshold
SNR_THRESH = 10;    % Minimum SNR to determine quality of calibration

%% Read Signal
% Check to see if Simulator Mode Flag was set from the GUI app
if exist('SIM_MODE','var')
    if SIM_MODE
        disp('Entering Simulator Mode...');
        % Disable READ_DSO flag
        READ_DSO = 0;
    else
        buildTxCal();
        % Enable the Read DSO flag
        READ_DSO = 1;
    end
% If not, prompt for the Data Source
else
    answer = questdlg('Data Source: ', ...
        'Data Source', ...
        'Read DSO','Load .mat File','Read DSO');
    % Handle response
    switch answer
        case 'Read DSO'
            % Build the ARB Files
            buildTxCal();
            READ_DSO = 1;
        case 'Load .mat File'
            READ_DSO = 0;
    end
end

% Init TX_CAL flag and Calibration Loop
RUN_TX_CAL = 1;
while RUN_TX_CAL
    %% Determine Data Source and Load Data
    if READ_DSO 
        % If READ_DSO Flag is set
        % Setup Rigol DSO using TxCal Mode Parameters
        setDSO(2,fb,[],VISAtype,VISAaddr);
        % Read in RF Data from DSO
        [ RFrx, trx ] = readDSO(1,1,VISAtype,VISAaddr);
        % Save the Uncalibrated Data
        save('Data Files\uncalibrated_RFrx.mat','RFrx','trx')
    else
        % Otherwise attempt to load simulator mode data
        if isfile('Data Files\uncalibrated_RFrx_sim.mat')
            load('Data Files\uncalibrated_RFrx_sim.mat');
        else
            % If the RFrx_sim.mat is found, prompt the user for a file
            [file,path] = uigetfile('*.mat','Select an RFrx Data file','uncalibrated_RFrx_sim.mat');
            
            % Verify Selection
            if isequal(file,0)
               disp('User selected Cancel');
            else
               disp(['User selected ', fullfile(path,file)]);
            end
            
            % Load The Data File
            load([path,file]);
            
        end
    end
    
    %% Calculate Sample Information
    Fsamp = 1/mean(diff(trx));
    Rxsps = round(Fsamp/fb);
    taps = round(Rxsps*0.8);
    
    %% AGC
    agc = rms(RFrx);
    RFrx = RFrx/agc/sqrt(2);
    
    %% Build Ideal rx symbols
    syncSyms = ((mSeq(N, Itaps)*2-1) + 1i*(mSeq(N, Qtaps)*2-1)).*exp(1i*pi/4)/sqrt(2);
    Nsyms = 2^N-1;
    
    %% Slice Uncompensated
    % Uncompensated Downconvert
    disp('Downconverting...')
    [Irx, Qrx] = downConvert(RFrx,fLO,Fsamp,taps);
    disp('Slicing Uncorrected...');
    unCorRx = frameSync(Irx,Qrx,syncSyms,Rxsps,Nsyms);   
    
    %% CFO Compensation
    disp('Detecting Carrier Frequency Offset...');
    % Blind Frequency Offset Estimation
    [Irx, Qrx] = downConvert(RFrx,fLO,Fsamp,taps);
    fErr = qpskCFO(Irx,Qrx,Fsamp);
    
    % Data Aided Frequency Estimation
    [Irx, Qrx] = downConvert(RFrx,fLO+fErr,Fsamp,taps);
    symsRx = frameSync(Irx,Qrx,syncSyms,Rxsps,Nsyms);
    fOff = fineCFO(syncSyms,symsRx, fb);
    fOff = fOff + fErr;
    
    % Downconvert with Frequency Adjusted LO
    [Irx, Qrx] = downConvert(RFrx,fLO+fOff,Fsamp,0);
    
    %% FIR Filter
    b = rcosdesign(1,1,round(Fsamp/fb));
    Irx = filter(b,1,Irx);
    Qrx = filter(b,1,Qrx);
    
    %% Frame Sync
    disp('Synchronizing...');
    [symsRx, sto, lag] = frameSync(Irx,Qrx,syncSyms,Rxsps,Nsyms);
    
    %% AGC
    symsRx = symsRx/mean(abs(symsRx)) * mean(abs(syncSyms));
    
    %% Phase Error Correction
    % I Symbol Indicies
    Indx = round(imag(syncSyms)) == 0;
    phaseOFF = (angle(symsRx(Indx)) - angle(syncSyms(Indx)))*180/pi;
    phaseOffset = mean(wrapTo180(phaseOFF));
    symsRx = symsRx.*exp(-1i*phaseOffset*pi/180);
    
    %% DC Offset
    Idc = mean(real(symsRx))-mean(real(syncSyms));
    Qdc = mean(imag(symsRx))-mean(imag(syncSyms));
    symsRx = symsRx - Idc - 1i*Qdc;
    
    %% Correction Calcs Index
    disp('Calculating Calibration Matrix...');
    % I and Q Symbol Indicies
    Qndx = round(real(syncSyms)) == 0;
    Indx = round(imag(syncSyms)) == 0;
    
    % Calculate Gain Mismatch
    alpha = mean(abs(symsRx(Qndx)))/mean(abs(symsRx(Indx)));
    
    % Isolate Q symbols
    qSyms = symsRx(Qndx);
    % Negative Q symbol indicies
    ndx = imag(qSyms)<0;
    % Rotate Negative Q symbols 180 degrees
    qSyms(ndx) = qSyms(ndx)*exp(1i*pi);
    % Calculate mean angle off Q axis
    phi = atan2d(mean(imag(qSyms)),mean(real(qSyms)))-90;
    
    % Build Calibration Matrix
    Ainv = [1 tand(phi);0 1/(alpha*cosd(phi))];
    
    %% Apply Correction
    rxCorrected = Ainv*[(real(symsRx))';(imag(symsRx))'];
    Irx2 = rxCorrected(1,:)';
    Qrx2 = rxCorrected(2,:)';
    symsRx2 = Irx2 + 1i*Qrx2;
    symsRx2 = symsRx2./mean(abs(symsRx2));
    
    %% Plot Results
    figure;
    plot(real(symsRx),imag(symsRx),'.',real(symsRx2),imag(symsRx2),'.','MarkerSize',5)
    pbaspect([1 1 1]);
    xlim([-1.5 1.5]);ylim([-1.5 1.5]);
    title('Transmitter Calibration Results');
    legend('Rx','Calibrated','Location','Best');
    grid on; grid minor;
    
    
    %% Print Results
    fprintf('\n------ Carrier Recovery and Sync ------\n');
    fprintf('Carrier Freq. Offset: %0.2f Hz\n',fOff);
    fprintf('Sample Timing Offset: %d samples\n',sto);
    fprintf('Symbol Index Offset : %d symbols\n',lag);
    
    
    %% SNR Check
    % Calculate a Noise Signal
    noiseRx = symsRx2 - syncSyms;
    % Calculate a Signal to Noise Power Ratio
    SNR = 10*log10(mean(abs(syncSyms).^2)/mean(abs(noiseRx).^2));
    % If SNR is below Threshold, alert user and prompt a re-cal try
    if SNR < SNR_THRESH
        beep
        answer = questdlg({['Calculated Signal to Noise Ratio is only:',num2str(SNR),' dB.'],'',...
            'Double check the ARBs have been synchronized','',...
            'Double check CH1 on DSO is reading the RF signal','',...
            'Re-Run the Tx Calibration? '}, ...
            'Re-Run Cal', ...
            'Yes','No','No');
        % Handle response
        switch answer
            case 'Yes'
                RUN_TX_CAL = 1;
                close
            case 'No'
                RUN_TX_CAL = 0;
                
        end
    else
        RUN_TX_CAL = 0;
    end
    
    fprintf('Signal to Noise     : %0.2f dB\n',SNR);
    fprintf('\n------ Calibration Coeffs -------\n');
    fprintf('phi  : %0.3f deg\n',phi);
    fprintf('alpha: %0.3f \n',alpha);
    fprintf('Idc  : %0.3f V\n',Idc);
    fprintf('Qdc  : %0.3f V\n\n',Qdc);
    
end

%% Save Data
% Check if Calibration Files folder exists, otherwise create the dir
if ~isfolder('Calibration Files')
    mkdir 'Calibration Files';
end
% Save Coefs in the Calibration Files
save('Calibration Files\txMixerCoefs.mat','Ainv','Idc','Qdc')
disp('Tx Cal Complete...');
disp('Calibration coeffiencts saved to "Calibration Files\txMixerCoefs.mat"');
