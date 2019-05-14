function [] = setRigol(mode,Fsym,Nsyms,instrumentType, intrumentAddress)
%% readRigol.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

% Function to read the Rigol Oscilloscope

% INPUTS:
%       mode
%                           1       - M-QAM Read
%                           2       - TxCal
%                           3       - RxCal
%                           4       - Analog Filters
%       Fsym                Symbol rate
%       Nsyms               Number of symbols for M-QAM Mode
%       instrumentType      VISA Instrument Type
%                           1       - NI
%                           2       - Agilent
%                           'xxxx'  - User Specified
%                           Default - KEYSIGHT
%       intrumentAddress    VISA Instrument Address, default Rigol DS4400


%% Input Check
if ~exist('instrumentType','var')
    % Default instrument type is KEYSIGHT
    instrumentType = 'KEYSIGHT';
end
if ~exist('intrumentAddress','var')
    % Default addresss
    intrumentAddress = 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR';
end

%% Set Instrument type if variable is numeric
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

%% Interface configuration and instrument connection
% Find a VISA-USB object.
visaObj = instrfind('Type', 'visa-usb', 'RsrcName', intrumentAddress, 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(visaObj)
    visaObj = visa(instrumentType, intrumentAddress);
else
    fclose(visaObj);
    visaObj = visaObj(1);
end

%% Set VISA Object Params
% Set the buffer size
visaObj.InputBufferSize = 2000000;
% Set the timeout value
visaObj.Timeout = 10;
% Set the Byte order
visaObj.ByteOrder = 'littleEndian';
% Open the connection
fopen(visaObj);

%% M-QAM Read Mode
if mode == 1
    %Set Time mode
    fprintf(visaObj,':TIMebase:MODE MAIN');
    fprintf(visaObj,':RUN');
    % Trigger off Channel 1
    fprintf(visaObj,':TRIGger:EDGe:SOURce CHANNEl1');
    % Set Trigger Level
    fprintf(visaObj,':TRIGger:EDGe:LEVel 0.25');
    % Turn on 20MHz Bandwidth Filters
    fprintf(visaObj,':CHANnel1:BWLimit 20M');
    fprintf(visaObj,':CHANnel2:BWLimit 20M');
    % Adjust Vertical Scale to 0.5 V/div
    fprintf(visaObj,':CHANnel1:SCALe 0.5');
    fprintf(visaObj,':CHANnel2:SCALe 0.5');
    % Turn Ch1 and Ch2 on, Turn Ch3 off
    fprintf(visaObj,':CHANnel1:DISP 1');
    fprintf(visaObj,':CHANnel2:DISP 1');
    fprintf(visaObj,':CHANnel3:DISP 0');
    % Set Memory Depth to 700k Points
    fprintf(visaObj,':ACQuire:MDEPth 700000');
    
    % Calculate Total Frame Length in Seconds
    T = Nsyms/Fsym;
    % Calculate a Time Scale Base using a tenth of two frame lengths
    ts = 2*T/10;
    fprintf(visaObj,[':TIMebase:SCALe ',num2str(ts)]);
    % Offset the trigger point by the length of the frame
    fprintf(visaObj,[':TIMebase:OFFSet ',num2str(T)]);
end


%% RX Cal Mode
if mode == 3
    %Set Time Mode and Run the DSO
    fprintf(visaObj,':TIMebase:MODE MAIN');
    fprintf(visaObj,':RUN');
    % Trigger off Channel 1
    fprintf(visaObj,':TRIGger:EDGe:SOURce CHANnel1');
    % Set Memory Depth to 700k Points
    fprintf(visaObj,':ACQuire:MDEPth 700000');
    % Turn on BW Filters
    fprintf(visaObj,':CHANnel1:BWLimit 20M');
    fprintf(visaObj,':CHANnel2:BWLimit 20M');
    % Set Vertical Scale to 0.5 V/div
    fprintf(visaObj,':CHANnel1:SCALe 0.5');
    fprintf(visaObj,':CHANnel2:SCALe 0.5');
    % Turn on Ch1,Ch2, Turn off Ch3
    fprintf(visaObj,':CHANnel1:DISP 1');
    fprintf(visaObj,':CHANnel2:DISP 1');
    fprintf(visaObj,':CHANnel3:DISP 0');
    % Calculate a Time Scale and Time offset based on the Symbol Rate
    ts = 2/Fsym;
    toff = ts*5;
    % Set Time Scale
    fprintf(visaObj,[':TIMebase:SCALe ',num2str(ts)]);
    fprintf(visaObj,[':TIMebase:OFFSet ',num2str(toff)]);
end

%% Analog Filter Mode
if mode == 4
    %Set Time Mode and Run the DSO
    fprintf(visaObj,':TIMebase:MODE MAIN');
    fprintf(visaObj,':RUN');
    % Trigger off Channel 3
    fprintf(visaObj,':TRIGger:EDGe:SOURce CHANnel3');
    % Set Bandwidth Filters
    fprintf(visaObj,':CHANnel1:BWLimit 20M');
    fprintf(visaObj,':CHANnel2:BWLimit 20M');
    fprintf(visaObj,':CHANnel3:BWLimit 20M');
    % Adjust Vertical Scales: V/div
    fprintf(visaObj,':CHANnel1:SCALe 0.5');
    fprintf(visaObj,':CHANnel2:SCALe 0.5');
    fprintf(visaObj,':CHANnel3:SCALe 1');
    % Turn on Ch 1,2,3
    fprintf(visaObj,':CHANnel1:DISP 1');
    fprintf(visaObj,':CHANnel2:DISP 1');
    fprintf(visaObj,':CHANnel3:DISP 1');
    % Set Time Scales
    fprintf(visaObj,':TIMebase:OFFSet 0.0001');
    fprintf(visaObj,':TIMebase:SCALe 0.00002');
    % Make sure DSO is running
    fprintf(visaObj,':RUN');
end


%% Delete objects and clear them.
delete(visaObj); clear visaObj;

end

