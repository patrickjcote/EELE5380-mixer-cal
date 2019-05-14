function [ V, t ] = readRigol( channel, reTrig, machID )

%% Interface configuration and instrument connection
% Find a VISA-USB object.
visaObj = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR', 'Tag', '');

if machID
    instrumentType = 'ni';
else
    instrumentType = 'agilent';
end

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(visaObj)
    visaObj = visa(instrumentType, 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR');
else
    fclose(visaObj);
    visaObj = visaObj(1);
end

% Set the buffer size
visaObj.InputBufferSize = 2000000;
% Set the timeout value
visaObj.Timeout = 10;
% Set the Byte order
visaObj.ByteOrder = 'littleEndian';
% Open the connection
fopen(visaObj);

% Single shot 
if reTrig
    fprintf(visaObj,':RUN');
    % Set MemDepth to 1.4M
    
    fprintf(visaObj,':SINGle');
    disp('Triggering DSO...');
    pause(2)
    status = query(visaObj, ':TRIGger:STATus?', '%s\n' ,'%s');
    while ~strcmp('STOP',status)
        pause(1);
        status = query(visaObj, ':TRIGger:STATus?', '%s\n' ,'%s');
    end
else
    fprintf(visaObj,':STOP');
end

% Specify data from Channel
fprintf(visaObj,[':WAVEFORM:SOURCE CHAN',num2str(channel)]);
disp(['Reading Channel ',num2str(channel)]);
fprintf(visaObj, ':WAV:MODE MAX');
% Specify 5000 points at a time by :WAV:DATA?
fprintf(visaObj,':WAV:POINTS:MODE RAW');
fprintf(visaObj,':WAV:POINTS 1400000');
operationComplete = str2double(query(visaObj,'*OPC?'));
while ~operationComplete
    operationComplete = str2double(query(visaObj,'*OPC?'));
end
% Get the data back as a WORD (i.e., INT16), other options are ASCII and BYTE
fprintf(visaObj,':WAVEFORM:FORMAT WORD');
% Set the byte order on the instrument as well
% fprintf(visaObj,':WAVEFORM:BYTEORDER LSBFirst');
% Get the preamble block
preambleBlock = query(visaObj,':WAVEFORM:PREAMBLE?');

% Now send commmand to read data
fprintf(visaObj,':WAV:DATA?');
% read back the BINBLOCK with the data in specified format and store it in
% the waveform structure. FREAD removes the extra terminator in the buffer
waveform.RawData = binblockread(visaObj,'uint16'); fread(visaObj,1);

% Read back the error queue on the instrument
% instrumentError = query(visaObj,':SYSTEM:ERR?');
% if ~isequal(instrumentError,['+0,"No error"' char(10)])
%     disp(['Instrument Error: ' instrumentError]);
%     instrumentError = query(visaObj,':SYSTEM:ERR?');
% end
% Close the VISA connection.
fclose(visaObj);


%% Data processing: Post process the data retreived from the scope
% Extract the X, Y data 

% Maximum value storable in a INT16
maxVal = 2^16;

%  split the preambleBlock into individual pieces of info
preambleBlock = regexp(preambleBlock,',','split');

% store all this information into a waveform structure for later use
waveform.Format = str2double(preambleBlock{1});     % This should be 1, since we're specifying INT16 output
waveform.Type = str2double(preambleBlock{2});
waveform.Points = str2double(preambleBlock{3});
waveform.Count = str2double(preambleBlock{4});      % This is always 1
waveform.XIncrement = str2double(preambleBlock{5}); % in seconds
waveform.XOrigin = str2double(preambleBlock{6});    % in seconds
waveform.XReference = str2double(preambleBlock{7});
waveform.YIncrement = str2double(preambleBlock{8}); % V
waveform.YOrigin = str2double(preambleBlock{9});
waveform.YReference = str2double(preambleBlock{10});
waveform.VoltsPerDiv = (maxVal * waveform.YIncrement / 8);      % V
waveform.Offset = ((maxVal/2 - waveform.YReference) * waveform.YIncrement + waveform.YOrigin);         % V
waveform.SecPerDiv = waveform.Points * waveform.XIncrement/10 ; % seconds
waveform.Delay = ((waveform.Points/2 - waveform.XReference) * waveform.XIncrement + waveform.XOrigin); % seconds

% Generate X & Y Data
waveform.XData = (waveform.XIncrement.*(1:length(waveform.RawData))) - waveform.XIncrement;
waveform.YData = (waveform.YIncrement.*(waveform.RawData - waveform.YReference)) + waveform.YOrigin;

t = waveform.XData;
V = waveform.YData;

% Delete objects and clear them.
delete(visaObj); clear visaObj;

end

