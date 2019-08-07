function [] = readMQAM(rxObj,DSOVisaType,DSOVisaAddr)
%% readMQAM.m
%
% Read an M-QAM signal from the DSO or supplied data.
% Bit Error Rates are calculated using known sent data.
% Rx Data is saved in 'Data Files' directory.
%
% INPUTS
%       rxObj.Fsym      Symbol Rate
%       rxObj.Nsyms 	Block Length in Symbols
%       rxObj.encBits   Known Transmit Bits
%       rxObj.dataBits  Known Data Bits
%       rxObj.rxCal     Apply Receiver Calibration Flag
%       rxObj.M         Modulation Order
%       rxObj.coding    Coding type (0-none,1-BCC,2-LDPC)
%       rxObj.blockLen  LDPC block length       [648,1296,1944]
%       rxObj.rate      LDPC rate ndx ( 1-4)->[ 1/2, 2/3, 3/4, 5/6]
%       rxObj.preM      Preamble m-seq order
%       rxObj.preTaps   Preamble m-seq taps
%
%       DSOVisaType     VISA Instrument Type
%                           1       - NI
%                           2       - Agilent
%                           'xxxx'  - User Specified
%                           Default - KEYSIGHT
%       DSOVisaAddress  VISA Instrument Address
%
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

format compact

%% Try Parsing rx object
try
    M = rxObj.M;
    Fsym = rxObj.Fsym;
    Nsyms = rxObj.Nsyms;
    TXdataBlock = rxObj.encBits;
    txBits = rxObj.dataBits;
    RX_CAL = rxObj.rxCal;
    CODING = rxObj.coding;
    preM = rxObj.preM;
    preTaps = rxObj.preTaps;
    itrs = rxObj.itrs;
    readItrs = rxObj.readItrs;
    SNRADD = rxObj.awgnSNR;
    
catch
    error('Rx Object not properly initialized.');
end


%% Check if Simulation Mode
global SIM_MODE
if isempty(SIM_MODE)
    SIM_MODE = 0;
end
if ~SIM_MODE
    READ_DSO = 1;
else
    READ_DSO = 0;
end

% Build progress bar

h = waitbar(0,'Connecting to the DSO...','Name',['Receiving ',num2str(readItrs),' blocks']);


totalErrors = comm.ErrorRate;
blockErrs = 0;
for N_READ = 1:readItrs
    fprintf('Receiving Block %d:\n',N_READ);
    % Update waitbar status
    msg = ['Receiving Block #',num2str(N_READ),'...'];
    waitbar(0.20*(N_READ/readItrs),h,msg);
    %% Get Data - Read DSO or Load File
    if READ_DSO
        % Check for VISA Address and Type, if none, set defaults
        if ~exist('DSOVisaAddr','var')
            disp('Setting default DSO address');
            DSOVisaAddr = 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR';
        end
        
        if ~exist('DSOVisaType','var')
            disp('Setting default DSO type');
            DSOVisaType = 'KEYSIGHT';
        end
        
        % Set DSO scaling based on Frame Size
        % TODO: Adjust setDSO Nsyms based on coding rate
        setDSO(1,Fsym,Nsyms+1024,DSOVisaType,DSOVisaAddr);
        % Read the signal from the DSO
        msg = ['Receiving Block #',num2str(N_READ),' - Reading Channel 1'];
        waitbar(0.40*(N_READ/readItrs),h,msg);
        [ Irx, ~ ] = readDSO(1,1,DSOVisaType,DSOVisaAddr);
        msg = ['Receiving Block #',num2str(N_READ),' - Reading Channel 2'];
        waitbar(0.60*(N_READ/readItrs),h,msg);
        [ Qrx, tq ] = readDSO(2,0,DSOVisaType,DSOVisaAddr);
        % Save The Data
        save(['Data Files\rxMqam_',num2str(M),'.mat'],'Irx','Qrx','tq');
    else
        % No Scope, prompt user for data file
        if N_READ == 1
            [file,path] = uigetfile('*.mat');
        end
        % Load the data file
        load([path,file])
    end
    
    %% Apply Rx Calibration Matrix if Flag
    if RX_CAL
        load('Calibration Files\rxMixerCoefs.mat');
        rxCor = Ainv*[(Irx-Idc)';(Qrx-Qdc)'];
        Irx = rxCor(1,:)'; Qrx = rxCor(2,:)';
    end
    
    %% AGC To Unity Power
    agc = mean(abs(Irx+1i*Qrx));
    Irx = Irx/agc;
    Qrx = Qrx/agc;
    
    %% Matched Filter - Assumes Square Pulse Shaping so Filter is Averaging FIR
    % TODO: Add customizable filter tuning
    % Build Filter Parameters
    fs = 1/mean(diff(tq));                      % Sample Rate
    Rxsps = round(fs/Fsym);                     % Samples per symbol
    K = 1;                                    % Filter Tune
    b = 1/Rxsps*K*ones(Rxsps*K,1);              % Filter Taps
    % Filter Signals
    Irx = filter(b,1,Irx);
    Qrx = filter(b,1,Qrx);
       
%     %% Sim Mode Add Noise
%     if SNRADD<100
%         clockSeed = clock;
%         rng(N_READ + round(clockSeed(6))*round(clockSeed(5)));
%         Crx = Irx + 1i*Qrx;
% %       Crx = awgn(Crx,SNRADD,'measured');
%         channel = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)','SNR',SNRADD);
%         Crx = channel(Crx);
%         Irx = real(Crx);
%         Qrx = imag(Crx);
%     end
    
    %% Frame Sync
    msg = ['Receiving Block #',num2str(N_READ),' - Synchronizing'];
    waitbar(0.70*(N_READ/readItrs),h,msg);
    % Build known sent symbols to use in synchronization
    syncSyms = ([mSeq(preM,preTaps);1]*2-1)*exp(1i*pi/4);               % Preamble M-sequence
    % Synchronize and slice
    [allSymsRx, sto, lag] = frameSync(Irx,Qrx,syncSyms,Rxsps,(length(syncSyms) + Nsyms));
    preRx = allSymsRx(1:length(syncSyms));
    dataSymsRx = allSymsRx(length(syncSyms)+1:end);
    
    %% AGC
    dataSymsRx = dataSymsRx/mean(abs(preRx)) * mean(abs(syncSyms));
    preRx = preRx/mean(abs(preRx)) * mean(abs(syncSyms));
    
    %% DC Offset
    Idc = mean(real(preRx))-mean(real(syncSyms));
    Qdc = mean(imag(preRx))-mean(imag(syncSyms));
    preRx = preRx - Idc - 1i*Qdc;
    dataSymsRx = dataSymsRx  - Idc - 1i*Qdc;
    %% Phase Offset Correction
    % Calculate phase offset
    phaseOFF = (angle(preRx) - angle(syncSyms))*180/pi;
    phaseOffset = mean(wrapTo180(phaseOFF));
    % Derotate symbols
    preRx = preRx.*exp(-1i*phaseOffset*pi/180);
    dataSymsRx = dataSymsRx.*exp(-1i*phaseOffset*pi/180);
    
        %% Sim Mode Add Noise
    if SNRADD<100
        clockSeed = clock;
        rng(N_READ + round(clockSeed(6))*round(clockSeed(5)));
        channel = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)','SNR',SNRADD);
        preRx = channel(preRx);
        dataSymsRx = channel(dataSymsRx);
    end
    
    %% Preamble SNR Calc
    noiseRx = preRx - syncSyms;
    SNR = 10*log10(mean(abs(syncSyms).^2)/mean(abs(noiseRx).^2))
    
    %% Demodulate and Decode
    msg = ['Receiving Block #',num2str(N_READ),' - Demod and Decod'];
    waitbar(0.90*(N_READ/readItrs),h,msg);
    codeType = 'Uncoded';
    if ~CODING
        rxBitsFull = qamdemod(dataSymsRx,M,'OutputType','bit','UnitAveragePower',true);
        
        % Remove padding
        if(mod(length(TXdataBlock),log2(M)))
            padBitsRx = log2(M)-mod(length(TXdataBlock),log2(M));
        else
            padBitsRx = 0;
        end
        rxBits = rxBitsFull(1:end-padBitsRx);
        
    else
        noiseVar = 10.^(-SNR/10);
        if noiseVar<5e-2
            noiseVar = 0.01;
        end
        
        % Remove padding
        if(mod(length(TXdataBlock),log2(M)))
            padBitsRx = log2(M)-mod(length(TXdataBlock),log2(M));
        else
            padBitsRx = 0;
        end
        ratesVec = {'1/2','2/3','3/4','5/6,','1/3'};
        if CODING == 1
            % conv decode
            rxLLRsFull = qamdemod(dataSymsRx,M,'OutputType','approxllr','UnitAveragePower',true);
            rxLLRs = rxLLRsFull(1:end-padBitsRx);
            rxBits = convDecode(rxLLRs,rxObj.rate);
            codeType = ['Conv. Coded. Rate ',ratesVec{rxObj.rate}];
        elseif CODING == 2
            % LDPC decode
            rxLLRsFull = qamdemod(dataSymsRx,M,'OutputType','llr','UnitAveragePower',true,'NoiseVariance',noiseVar);
            rxLLRs = rxLLRsFull(1:end-padBitsRx);
            rxBits = double(ldpcDecode(rxLLRs,rxObj.blockLen,rxObj.rate,itrs));
            codeType = ['LDPC Coded. Rate ',ratesVec{rxObj.rate}];
        elseif CODING == 3
            % turbo decode
            rxLLRsFull = qamdemod(dataSymsRx,M,'OutputType','approxllr','UnitAveragePower',true,'NoiseVariance',noiseVar);
            rxLLRs = rxLLRsFull(1:end-padBitsRx);
            rxBits = turbDecode(rxLLRs,length(txBits),itrs);
            codeType = ['Turbo Coded. Rate ',ratesVec{rxObj.rate}];
        end
    end
    
    %% Calculate BER
    % Update Progress Bar
    msg = ['Receiving Block #',num2str(N_READ),' - Calculating Bit Errors'];
    waitbar(0.95*(N_READ/readItrs),h,msg);
    totalErrorStats = totalErrors(txBits,rxBits);
    if sum(txBits ~= rxBits)
        blockErrs = blockErrs+1;
    end
    
    itrErrors = comm.ErrorRate;
    itrErrorStats = itrErrors(txBits,rxBits);
    BER = itrErrorStats(1)
    bit_errors = itrErrorStats(2)
    totalBits = itrErrorStats(3)
    
    % Update Progress Bar
    msg = ['Receiving Block #',num2str(N_READ),' - Successful'];
    waitbar(1*(N_READ/readItrs),h,msg);
end

% Close Progress Bar
close(h);           % close status bar

%% Load Error Stats
BER = totalErrorStats(1);
bit_errors = totalErrorStats(2);
totalBits = totalErrorStats(3);
BLER = blockErrs/readItrs;

%% Report SNR and BER Stats
mBox.Interpreter = 'tex';
mBox.WindowStyle = 'replace';
mBox.Message = {'\fontsize{20}';
    ['SNR:         ',num2str(SNR),' dB'];
    ' ';
    '\bfError Stats:\rm\fontsize{15}';
    ['     BER:             ',num2str(BER)];
    ['     BLER:           ',num2str(BLER)];
    ['     Total Errors:   ',num2str(bit_errors)];
    ['     Total Bits:    ',num2str(totalBits)];
    ' ';
    };
% msgbox(mBox.Message,'Results',mBox);
clear mBox

%% Plot Received Symbols and Symbols in Error
% TODO: Think about symbols in error when FEC coding is used
% Find bit errors
errs = (rxBits ~= txBits);
% Calculate a symbol index for each bit error
ndx = ceil(find(errs==1)/log2(M));
% Plot
figure('name',[num2str(M),'-QAM ',codeType,' @ SNR: ',num2str(SNR),' dB'],'NumberTitle','off')
hold on;
plot(real(dataSymsRx),imag(dataSymsRx),'.','MarkerSize',10)
plot(real(dataSymsRx(ndx)),imag(dataSymsRx(ndx)),'r*','MarkerSize',15)
pbaspect([1 1 1]);
axis([-1.1 1.1 -1.1 1.1]*max(abs(dataSymsRx)));
xlabel('I');ylabel('Q');
titleBER = {[num2str(M),'-QAM ',codeType,' @ SNR: ',num2str(SNR),' dB'];
    ['BER: ',num2str(BER),'   BLER: ',num2str(BLER),'    Total Errors:   ',num2str(bit_errors),'   Total Bits:    ',num2str(totalBits)];
    };
title(titleBER);
grid on; grid minor;