%% Interface configuration and instrument connection% Find a VISA-USB object.
visaObj = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR', 'Tag', '');
machID = 1;
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

%% Set Trigger
fprintf(visaObj,':TIMebase:MODE MAIN');
    fprintf(visaObj,':RUN');
fprintf(visaObj,':TRIGger:EDGe:SOURce CHANnel1');

fprintf(visaObj,':CHANnel1:BWLimit 20M');

fprintf(visaObj,':CHANnel1:SCALe 0.5');

fprintf(visaObj,':CHANnel1:DISP 1');
fprintf(visaObj,':CHANnel2:DISP 0');
fprintf(visaObj,':CHANnel3:DISP 0');

    fprintf(visaObj,':ACQuire:MDEPth 1400000');
    pause(2)
    fprintf(visaObj,':SINGle');

ts = 0.2;
toff = ts*5;
fprintf(visaObj,[':TIMebase:SCALe ',num2str(ts)]);
fprintf(visaObj,[':TIMebase:OFFSet ',num2str(toff)]);



%% Delete objects and clear them.
delete(visaObj); clear visaObj;