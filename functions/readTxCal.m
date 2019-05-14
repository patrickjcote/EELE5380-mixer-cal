% readTxCal.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems
% Step 1 in the TIMS Tx calibration
close all;  clc;

RUN_TX_CAL = 1;

%% Cal Parameters
fb = 5e3;           % Baseband Signal frequency         [Symbols/s]
fLO = 100e3;        % Ideal Local Oscillator Freq       [Hz]

N = 10;             % Number of shift registers for m seq generation
Itaps = [10 9 5 2]; % Feedback Taps for I seq
Qtaps = [10 9 7 6]; % Feedback Taps for Q seq

%% Read Signal

if exist('SIM_MODE','var')
    if SIM_MODE
        disp('simmode');
        READ_DSO = 0;
    else
        questdlg('Recall state: "STATE_Tx_cal_01.sta" on the AWG',...
    'Analog Filter Cal', ...
            'Ok','Ok');
        READ_DSO = 1;
    end
    
else
    answer = questdlg('Data Source: ', ...
        'Data Source', ...
        'Read DSO','Load .mat File','Read DSO');
    % Handle response
    switch answer
        case 'Read DSO'
            READ_DSO = 1;
        case 'Load .mat File'
            READ_DSO = 0;
    end
end

while RUN_TX_CAL
    % READ RF SIGNAL USING DSO
    if READ_DSO
        setRigol_txCal
        pause(2)
        [ RFrx, trx ] = readRigol(1,1,1);
        save('functions\uncalibrated_RFrx.mat','RFrx','trx')
    else
        if isfile('functions\uncalibrated_RFrx_sim.mat')
            load('functions\uncalibrated_RFrx_sim.mat');
        else
            [file,path] = uigetfile('*.mat');
            load([path,file])
        end
    end
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
    
    figure;
    plot(real(symsRx),imag(symsRx),'.',real(symsRx2),imag(symsRx2),'.','MarkerSize',5)
    pbaspect([1 1 1]);
    xlim([-1.5 1.5]);ylim([-1.5 1.5]);
    %     title('Transmitter Calibration Results');
    legend('Rx','Calibrated','Location','Best');
    grid on; grid minor;
    
    
    %% Results
    % Print
    fprintf('\n------ Carrier Recovery and Sync ------\n');
    fprintf('Carrier Freq. Offset: %0.2f Hz\n',fOff);
    fprintf('Sample Timing Offset: %d samples\n',sto);
    fprintf('Symbol Index Offset : %d symbols\n',lag);
    
    
    %% SNR Calc
    noiseRx = symsRx2 - syncSyms;
    SNR = 10*log10(mean(abs(syncSyms).^2)/mean(abs(noiseRx).^2));
    if SNR < 10
        beep
        SNR
        answer = questdlg({['Calculated Signal to Noise Ratio is only:',num2str(SNR),' dB.'],'',...
            'Double check the ARBs have been synchronized','',...
            'Double check CH1 on DSO is reading the RF signal','',...
            'Re-Run the Tx Calibration '}, ...
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
save('functions\Parameter Files\txMixerCoefs.mat','Ainv','Idc','Qdc')
disp('Tx Cal Complete...');
disp('Calibration coeffiencts saved to "functions\Parameter Files\txMixerCoefs.mat"');
