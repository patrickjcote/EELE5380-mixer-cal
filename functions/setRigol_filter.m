%% Interface configuration and instrument connection% Find a VISA-USB object.

questdlg('Recall state: "STATE_IMPULSE.sta" on the AWG',...
    'Analog Filter Cal', ...
            'Ok','Ok');
%%

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

fprintf(visaObj,':TRIGger:EDGe:SOURce CHANnel3');

fprintf(visaObj,':CHANnel1:BWLimit 20M');
fprintf(visaObj,':CHANnel2:BWLimit 20M');
fprintf(visaObj,':CHANnel3:BWLimit 20M');

fprintf(visaObj,':CHANnel1:SCALe 0.5');
fprintf(visaObj,':CHANnel2:SCALe 0.5');
fprintf(visaObj,':CHANnel3:SCALe 1');

fprintf(visaObj,':CHANnel1:DISP 1');
fprintf(visaObj,':CHANnel2:DISP 1');
fprintf(visaObj,':CHANnel3:DISP 1');

fprintf(visaObj,':TIMebase:OFFSet 0.0001');
fprintf(visaObj,':TIMebase:SCALe 0.00002');

fprintf(visaObj,':RUN');

%% Delete objects and clear them.
delete(visaObj); clear visaObj;

%%
questdlg({'View the filters response on the DSO','','Adjust the "Tune" and "Gain" Knobs until the','Impulse responses line up' }, ...
            'Analog Filter Cal', ...
            'Ok','Ok');