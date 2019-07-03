classdef mqamApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        MQAMSystemv05UIFigure          matlab.ui.Figure
        TabGroup                       matlab.ui.container.TabGroup
        TxRxTab                        matlab.ui.container.Tab
        SendButton                     matlab.ui.control.StateButton
        ReadButton                     matlab.ui.control.StateButton
        QAMOrderDropDownLabel          matlab.ui.control.Label
        QAMOrderDropDown               matlab.ui.control.DropDown
        Status                         matlab.ui.control.Label
        ForwardErrorCorrectionButtonGroup  matlab.ui.container.ButtonGroup
        NoneButton                     matlab.ui.control.RadioButton
        ConvolutionalButton            matlab.ui.control.RadioButton
        LDPCButton                     matlab.ui.control.RadioButton
        RateDropDown                   matlab.ui.control.DropDown
        LDPCBlockLengthDropDown        matlab.ui.control.DropDown
        LDPCBlockLengthDropDownLabel   matlab.ui.control.Label
        RateDropDownLabel              matlab.ui.control.Label
        TurboButton                    matlab.ui.control.RadioButton
        BlockSettingsTab               matlab.ui.container.Tab
        BlockLengthsymbolsEditFieldLabel  matlab.ui.control.Label
        BlockLengthsymbolsEditField    matlab.ui.control.NumericEditField
        RandomSeedEditFieldLabel       matlab.ui.control.Label
        RandomSeedEditField            matlab.ui.control.NumericEditField
        SymbolRatesymssecEditFieldLabel  matlab.ui.control.Label
        SymbolRatesymssecEditField     matlab.ui.control.NumericEditField
        ApplyTxCalibrationSwitchLabel  matlab.ui.control.Label
        ApplyTxCalibrationSwitch       matlab.ui.control.ToggleSwitch
        ApplyRxCalibrationSwitchLabel  matlab.ui.control.Label
        ApplyRxCalibrationSwitch       matlab.ui.control.ToggleSwitch
        SyncPreambleLengthDropDownLabel  matlab.ui.control.Label
        SyncPreambleLengthDropDown     matlab.ui.control.DropDown
        DeviceSettingsTab              matlab.ui.container.Tab
        ScopeDropDownLabel             matlab.ui.control.Label
        ScopeDropDown                  matlab.ui.control.DropDown
        AWGDropDownLabel               matlab.ui.control.Label
        AWGDropDown                    matlab.ui.control.DropDown
        RefreshDeviceListButton        matlab.ui.control.Button
        RefreshLamp                    matlab.ui.control.Lamp
        EnableSimulatorModeCheckBox    matlab.ui.control.CheckBox
    end

    
    methods (Access = private)
        
        function results = refreshDevices(app)
            
            % Set Lamp Color
            app.RefreshLamp.Color = 'Yellow';
            % Reset DropDown options
            app.ScopeDropDown.Items = {''};
            app.ScopeDropDown.ItemsData = {''};
            app.AWGDropDown.Items = {''};
            app.AWGDropDown.ItemsData = {''};
            % Disable Buttons
            app.SendButton.Enable = 0;
            app.ReadButton.Enable = 0;
            % Force a redraw of GUI
            drawnow
            
            % Find Devices
            devices = scanVISA();
            %           load('Data Files\scanVisaOutput3.mat','devices');
            
            if ~iscell(devices)
                % Devices structure is empty, load Items
                app.ScopeDropDown.Items{1} = 'No Devices Found.';
                app.AWGDropDown.Items{1} = 'No Devices Found.';
                % Force App to select Device Setting Tab
                app.TabGroup.SelectedTab = app.DeviceSettingsTab;
                % Set status lamp color
                app.RefreshLamp.Color = 'Red';
                % Disable Calibration Function Buttons
                %                 app.SendButton.Enable = 0;
                %                 app.ReadButton.Enable = 0;
                app.Status.Text = 'No Devices Available.';
                app.Status.FontColor = [0.64 0.08 0.18];
                % Sound
                beep
                % Return 0
                results = 0;
                return;
            else
                % Otherwise Load dropowns with found devices
                % Initialize DropDown index
                awgNDX = 1;
                dsoNDX = 1;
                % For each device found
                for n = 1:length(devices)
                    % Load the Device Name as the Dropdown Text
                    % Load the device structure into the Dropdown data
                    app.ScopeDropDown.Items{n} = devices{n}.IDN;
                    app.ScopeDropDown.ItemsData{n} = devices{n};
                    app.AWGDropDown.Items{n} = devices{n}.IDN;
                    app.AWGDropDown.ItemsData{n} = devices{n};
                    
                    % Test IDs to Set Defaults (DSO->Rigol, AWG->Agilent);
                    if strncmpi('Agilent',devices{n}.IDN,7)
                        awgNDX = n;
                    elseif strncmpi('Rigol',devices{n}.IDN,5)
                        dsoNDX = n;
                    end
                end
                
                % If there is more than one device detected, set the dropdown boxes to
                % to the appropriate devices for specified defaults
                if length(devices)>1
                    app.ScopeDropDown.Value = devices{dsoNDX};
                    app.AWGDropDown.Value = devices{awgNDX};
                end
                
                % Enable Run Function Buttons
                app.SendButton.Enable = 1;
                app.ReadButton.Enable = 1;
                app.Status.Text = '';
                
                % Device refresh successful, set lamp to green
                app.RefreshLamp.Color = 'Green';
            end
            
        end
        
        function [encBlock, dataBits] = buildencBlock(app)
            
            selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
            
            M = str2num(app.QAMOrderDropDown.Value);
            N_syms = app.BlockLengthsymbolsEditField.Value;
            rng_seed = app.RandomSeedEditField.Value;
            
            switch selectedButton.Text
                case 'None' % No channel coding
                    rng(rng_seed);          % Random Seed
                    dataBits = randi([0 1],log2(M)*N_syms,1);
                    encBlock = dataBits;
                case 'Convolutional'
                    % Convolutional Coding
                    % Load Rate
                    rate = str2num(app.RateDropDown.Value);

                    switch rate
                        case 3
                            r = 3/4;
                        case 2
                            r = 2/3;
                        case 4
                            r = 5/6;
                        otherwise
                            r = 1/2;
                    end
                    
                    NdataBits = log2(M)*N_syms;
                    rng(rng_seed);          % Random Seed
                    dataBits = randi([0 1],NdataBits,1);
                    % Tail bits to flush the encoder
                    dataBits(end-31:end) = zeros(32,1);
                    encBlock = convEncode(dataBits,rate);

                        
                case 'LDPC'
                    blockLen = str2num(app.LDPCBlockLengthDropDown.Value);
                    rate = str2num(app.RateDropDown.Value);
                    [encBlock, dataBits] = ldpcEncode(blockLen,rate,rng_seed);
                otherwise
                    rng(rng_seed);          % Random Seed
                    dataBits = randi([0 1],log2(M)*N_syms,1);
                    encBlock = dataBits;
            end
            
        end
        
        function results = berCheck(app,dataRx)
            %% Error Calc
            errs = sum(dataRx ~= dataTx)
            BER = errs/length(dataRx);
            
            disp(['BER: ',num2str(BER)]);
            
            %% Plot
            figure;
            errs = dataRx ~= dataTx;
            ndx = ceil(find(errs==1)/log2(M));
            plot(real(symsRx),imag(symsRx),'.',real(symsRx(ndx)),imag(symsRx(ndx)),'r.')
            pbaspect([1 1 1]);
            axis([-1.5 1.5 -1.5 1.5]);
            xlabel('I');ylabel('Q');
            title('Received Constellation');
            grid on; grid minor;
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            addpath('functions\');
            
            % Initialize Channel Coding
            app.RateDropDown.Visible = 0;
            app.RateDropDownLabel.Visible = 0;
            app.LDPCBlockLengthDropDown.Visible = 0;
            app.LDPCBlockLengthDropDownLabel.Visible = 0;
            
            % Set Lamp
            app.RefreshLamp.Color = 'Yellow';
            refreshDevices(app);
            
        end

        % Value changed function: SendButton
        function SendButtonValueChanged(app, event)
            
            app.Status.Text = 'Starting Transmit...';
            app.Status.FontColor = 'Black';
            
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
            
            if ~SIM_MODE
                AWGVisa = app.AWGDropDown.Value;
                AWGVisaType = AWGVisa.type;
                AWGVisaAddr = AWGVisa.addr;
            else
                AWGVisaType = '';
                AWGVisaAddr = '';
            end
            
            
            switch app.ApplyTxCalibrationSwitch.Value
                case 'Off'
                    TX_CAL = 0;
                otherwise
                    TX_CAL = 1;
            end
            
            % Load Tx Object
            txObj.Fsym = app.SymbolRatesymssecEditField.Value;
            txObj.Nsyms = app.BlockLengthsymbolsEditField.Value;
            
            try
                [encBlock, dataBits] = buildencBlock(app);
            catch ME
                warning('Error Running buildencBlock');
                warning(ME.message);
                app.Status.Text = 'An Error Occured. Check Command Window for details.';
                app.Status.FontColor = [0.64 0.08 0.18];
                return
            end
            
            
            txObj.encBits = encBlock;
            txObj.dataBits = dataBits;
            txObj.txCal = TX_CAL;
            txObj.M = str2num(app.QAMOrderDropDown.Value);
            
            % Load Preamble Length, Set M-seq order and taps
            switch str2num(app.SyncPreambleLengthDropDown.Value)
                case 256
                    txObj.preM = 8;
                    txObj.preTaps = [8, 6, 5, 4];
                case 512
                    txObj.preM = 9;
                    txObj.preTaps = [9, 8, 6, 5];
                case 1024
                    txObj.preM = 10;
                    txObj.preTaps = [10, 9, 7, 6];
                case 2048
                    txObj.preM = 11;
                    txObj.preTaps = [11, 10, 9, 7];
                otherwise
                    txObj.preM = 10;
                    txObj.preTaps = [10, 9, 7, 6];
            end
            
            try
                buildMQAM(txObj,2,AWGVisaType,AWGVisaAddr);
                app.Status.FontColor = [0.47 0.67 0.19];
                app.Status.Text = 'Send Successful.';
            catch ME
                warning('Error Running buildMQAM');
                warning(ME.message);
                app.Status.Text = 'An Error Occured. Check Command Window for details.';
                app.Status.FontColor = [0.64 0.08 0.18];
                
            end
            
            % Unpress send button
            app.SendButton.Value = 0;
            
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv05UIFigure.Visible = 0;
            app.MQAMSystemv05UIFigure.Visible = 1;
            
        end

        % Value changed function: ReadButton
        function ReadButtonValueChanged(app, event)
            
            app.Status.Text = 'Starting Receive...';
            app.Status.FontColor = 'Black';
            
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
            
            if ~SIM_MODE
                DSOVisa = app.ScopeDropDown.Value;
                DSOVisaType = DSOVisa.type;
                DSOVisaAddr = DSOVisa.addr;
            else
                DSOVisaType = '';
                DSOVisaAddr = '';
            end
            
            switch app.ApplyRxCalibrationSwitch.Value
                case 'Off'
                    RX_CAL = 0;
                otherwise
                    RX_CAL = 1;
            end
            
            % Load Tx Object
            txObj.Fsym = app.SymbolRatesymssecEditField.Value;
            txObj.Nsyms = app.BlockLengthsymbolsEditField.Value;
            txObj.rxCal = RX_CAL;
            txObj.M = str2num(app.QAMOrderDropDown.Value);
            
            % Load Preamble Length, Set M-seq order and taps
            switch str2num(app.SyncPreambleLengthDropDown.Value)
                case 256
                    txObj.preM = 8;
                    txObj.preTaps = [8, 6, 5, 4];
                case 512
                    txObj.preM = 9;
                    txObj.preTaps = [9, 8, 6, 5];
                case 1024
                    txObj.preM = 10;
                    txObj.preTaps = [10, 9, 7, 6];
                case 2048
                    txObj.preM = 11;
                    txObj.preTaps = [11, 10, 9, 7];
                otherwise
                    txObj.preM = 10;
                    txObj.preTaps = [10, 9, 7, 6];
            end
            
            
            [encBlock, dataBits] = buildencBlock(app);
            txObj.encBits = encBlock;
            txObj.dataBits = dataBits;
            ratesVec = [1/2 2/3 3/4 5/6];
            
            % Load Coding Scheme into Tx Object
            selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
            switch selectedButton.Text
                case 'None' % No channel coding
                    txObj.coding = 0;
                case 'Convolutional'
                    txObj.coding = 1;
                    txObj.rate = str2num(app.RateDropDown.Value);
                    txObj.Nsyms = txObj.Nsyms/ratesVec(txObj.rate);
                case 'LDPC'
                    txObj.blockLen = str2num(app.LDPCBlockLengthDropDown.Value);
                    txObj.rate = str2num(app.RateDropDown.Value);
                    txObj.coding = 2;
                    txObj.Nsyms = str2num(app.LDPCBlockLengthDropDown.Value)/(log2(txObj.M));
                otherwise
            end
                               
                    try
                        readMQAM(txObj,DSOVisaType,DSOVisaAddr);
                        app.Status.FontColor = [0.47 0.67 0.19];
                        app.Status.Text = 'Read Successful.';
                    catch ME
                        warning('Error Running readMQAM');
                        warning(ME.message);
                        app.Status.Text = 'An Error Occured. Check Command Window for details.';
                        app.Status.FontColor = [0.64 0.08 0.18];
                    end
                    
                    app.ReadButton.Value = 0;
                    
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv05UIFigure.Visible = 0;
            app.MQAMSystemv05UIFigure.Visible = 1;
        end

        % Button pushed function: RefreshDeviceListButton
        function RefreshDeviceListButtonPushed(app, event)
                refreshDevices(app);
        end

        % Value changed function: EnableSimulatorModeCheckBox
        function EnableSimulatorModeCheckBoxValueChanged(app, event)
                global SIM_MODE
                SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
                
                if SIM_MODE
                    % Enable Calibration Function Buttons
                    app.SendButton.Enable = 1;
                    app.ReadButton.Enable = 1;
                    app.ApplyRxCalibrationSwitch.Value = 'Off';
                    app.ApplyTxCalibrationSwitch.Value = 'Off';
                    app.Status.FontColor = [0.47 0.67 0.19];
                    app.Status.Text = 'Entered Simulator Mode.';
                else
                    app.ApplyRxCalibrationSwitch.Value = 'On';
                    app.ApplyTxCalibrationSwitch.Value = 'On';
                    refreshDevices(app);
                end
        end

        % Selection changed function: 
        % ForwardErrorCorrectionButtonGroup
        function ForwardErrorCorrectionButtonGroupSelectionChanged(app, event)
                selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
                
                switch selectedButton.Text
                    case 'None'
                        app.RateDropDown.Visible = 0;
                        app.RateDropDownLabel.Visible = 0;
                        app.LDPCBlockLengthDropDown.Visible = 0;
                        app.LDPCBlockLengthDropDownLabel.Visible = 0;
                        app.BlockLengthsymbolsEditField.Enable = 1;
                    case 'Convolutional'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.LDPCBlockLengthDropDown.Visible = 0;
                        app.LDPCBlockLengthDropDownLabel.Visible = 0;
                        app.BlockLengthsymbolsEditField.Enable = 1;
                    case 'LDPC'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.LDPCBlockLengthDropDown.Visible = 1;
                        app.LDPCBlockLengthDropDownLabel.Visible = 1;
                        app.BlockLengthsymbolsEditField.Enable = 0;
                    otherwise
                        app.RateDropDown.Visible = 0;
                        app.LDPCBlockLengthDropDown.Visible = 0;
                end
                
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create MQAMSystemv05UIFigure and hide until all components are created
            app.MQAMSystemv05UIFigure = uifigure('Visible', 'off');
            app.MQAMSystemv05UIFigure.Position = [100 100 396 370];
            app.MQAMSystemv05UIFigure.Name = 'M-QAM System - v0.5';
            app.MQAMSystemv05UIFigure.Resize = 'off';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.MQAMSystemv05UIFigure);
            app.TabGroup.Position = [1 -8 397 379];

            % Create TxRxTab
            app.TxRxTab = uitab(app.TabGroup);
            app.TxRxTab.Title = 'Tx/Rx';

            % Create SendButton
            app.SendButton = uibutton(app.TxRxTab, 'state');
            app.SendButton.ValueChangedFcn = createCallbackFcn(app, @SendButtonValueChanged, true);
            app.SendButton.Text = 'Send';
            app.SendButton.Position = [60 55 100 22];

            % Create ReadButton
            app.ReadButton = uibutton(app.TxRxTab, 'state');
            app.ReadButton.ValueChangedFcn = createCallbackFcn(app, @ReadButtonValueChanged, true);
            app.ReadButton.Text = 'Read';
            app.ReadButton.Position = [239 55 100 22];

            % Create QAMOrderDropDownLabel
            app.QAMOrderDropDownLabel = uilabel(app.TxRxTab);
            app.QAMOrderDropDownLabel.Position = [60 307 67 22];
            app.QAMOrderDropDownLabel.Text = 'QAM Order';

            % Create QAMOrderDropDown
            app.QAMOrderDropDown = uidropdown(app.TxRxTab);
            app.QAMOrderDropDown.Items = {'4', '16', '32', '64', '128', '256', '512', '1024'};
            app.QAMOrderDropDown.Editable = 'on';
            app.QAMOrderDropDown.BackgroundColor = [1 1 1];
            app.QAMOrderDropDown.Position = [194 307 144 22];
            app.QAMOrderDropDown.Value = '4';

            % Create Status
            app.Status = uilabel(app.TxRxTab);
            app.Status.HorizontalAlignment = 'center';
            app.Status.Position = [47 12 302 22];
            app.Status.Text = '';

            % Create ForwardErrorCorrectionButtonGroup
            app.ForwardErrorCorrectionButtonGroup = uibuttongroup(app.TxRxTab);
            app.ForwardErrorCorrectionButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ForwardErrorCorrectionButtonGroupSelectionChanged, true);
            app.ForwardErrorCorrectionButtonGroup.Title = 'Forward Error Correction';
            app.ForwardErrorCorrectionButtonGroup.Position = [29 163 338 123];

            % Create NoneButton
            app.NoneButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.NoneButton.Text = 'None';
            app.NoneButton.Position = [11 77 58 22];
            app.NoneButton.Value = true;

            % Create ConvolutionalButton
            app.ConvolutionalButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.ConvolutionalButton.Text = 'Convolutional';
            app.ConvolutionalButton.Position = [11 55 95 22];

            % Create LDPCButton
            app.LDPCButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCButton.Text = 'LDPC';
            app.LDPCButton.Position = [11 33 65 22];

            % Create RateDropDown
            app.RateDropDown = uidropdown(app.ForwardErrorCorrectionButtonGroup);
            app.RateDropDown.Items = {'1/2', '2/3', '3/4', '5/6'};
            app.RateDropDown.ItemsData = {'1', '2', '3', '4'};
            app.RateDropDown.Position = [226 76 100 22];
            app.RateDropDown.Value = '1';

            % Create LDPCBlockLengthDropDown
            app.LDPCBlockLengthDropDown = uidropdown(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCBlockLengthDropDown.Items = {'648', '1296', '1944'};
            app.LDPCBlockLengthDropDown.ItemsData = {'648', '1296', '1944'};
            app.LDPCBlockLengthDropDown.Position = [226 34 100 22];
            app.LDPCBlockLengthDropDown.Value = '648';

            % Create LDPCBlockLengthDropDownLabel
            app.LDPCBlockLengthDropDownLabel = uilabel(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCBlockLengthDropDownLabel.HorizontalAlignment = 'right';
            app.LDPCBlockLengthDropDownLabel.Position = [142 33 75 22];
            app.LDPCBlockLengthDropDownLabel.Text = 'Block Length';

            % Create RateDropDownLabel
            app.RateDropDownLabel = uilabel(app.ForwardErrorCorrectionButtonGroup);
            app.RateDropDownLabel.HorizontalAlignment = 'right';
            app.RateDropDownLabel.Position = [180 76 31 22];
            app.RateDropDownLabel.Text = 'Rate';

            % Create TurboButton
            app.TurboButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.TurboButton.Enable = 'off';
            app.TurboButton.Text = 'Turbo';
            app.TurboButton.Position = [11 12 65 22];

            % Create BlockSettingsTab
            app.BlockSettingsTab = uitab(app.TabGroup);
            app.BlockSettingsTab.Title = 'Block Settings';

            % Create BlockLengthsymbolsEditFieldLabel
            app.BlockLengthsymbolsEditFieldLabel = uilabel(app.BlockSettingsTab);
            app.BlockLengthsymbolsEditFieldLabel.Position = [60 238 130 22];
            app.BlockLengthsymbolsEditFieldLabel.Text = 'Block Length (symbols)';

            % Create BlockLengthsymbolsEditField
            app.BlockLengthsymbolsEditField = uieditfield(app.BlockSettingsTab, 'numeric');
            app.BlockLengthsymbolsEditField.Position = [238 238 100 22];
            app.BlockLengthsymbolsEditField.Value = 2000;

            % Create RandomSeedEditFieldLabel
            app.RandomSeedEditFieldLabel = uilabel(app.BlockSettingsTab);
            app.RandomSeedEditFieldLabel.Position = [58 202 82 22];
            app.RandomSeedEditFieldLabel.Text = 'Random Seed';

            % Create RandomSeedEditField
            app.RandomSeedEditField = uieditfield(app.BlockSettingsTab, 'numeric');
            app.RandomSeedEditField.Position = [238 202 100 22];
            app.RandomSeedEditField.Value = 2369;

            % Create SymbolRatesymssecEditFieldLabel
            app.SymbolRatesymssecEditFieldLabel = uilabel(app.BlockSettingsTab);
            app.SymbolRatesymssecEditFieldLabel.Position = [60 271 136 22];
            app.SymbolRatesymssecEditFieldLabel.Text = 'Symbol Rate (syms/sec)';

            % Create SymbolRatesymssecEditField
            app.SymbolRatesymssecEditField = uieditfield(app.BlockSettingsTab, 'numeric');
            app.SymbolRatesymssecEditField.Position = [238 271 100 22];
            app.SymbolRatesymssecEditField.Value = 1000;

            % Create ApplyTxCalibrationSwitchLabel
            app.ApplyTxCalibrationSwitchLabel = uilabel(app.BlockSettingsTab);
            app.ApplyTxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyTxCalibrationSwitchLabel.Position = [58 105 113 22];
            app.ApplyTxCalibrationSwitchLabel.Text = 'Apply Tx Calibration';

            % Create ApplyTxCalibrationSwitch
            app.ApplyTxCalibrationSwitch = uiswitch(app.BlockSettingsTab, 'toggle');
            app.ApplyTxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyTxCalibrationSwitch.Position = [97 81 38 16];
            app.ApplyTxCalibrationSwitch.Value = 'On';

            % Create ApplyRxCalibrationSwitchLabel
            app.ApplyRxCalibrationSwitchLabel = uilabel(app.BlockSettingsTab);
            app.ApplyRxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyRxCalibrationSwitchLabel.Position = [226 105 118 22];
            app.ApplyRxCalibrationSwitchLabel.Text = ' Apply Rx Calibration';

            % Create ApplyRxCalibrationSwitch
            app.ApplyRxCalibrationSwitch = uiswitch(app.BlockSettingsTab, 'toggle');
            app.ApplyRxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyRxCalibrationSwitch.Position = [266 82 38 16];
            app.ApplyRxCalibrationSwitch.Value = 'On';

            % Create SyncPreambleLengthDropDownLabel
            app.SyncPreambleLengthDropDownLabel = uilabel(app.BlockSettingsTab);
            app.SyncPreambleLengthDropDownLabel.Position = [58 166 127 22];
            app.SyncPreambleLengthDropDownLabel.Text = 'Sync Preamble Length';

            % Create SyncPreambleLengthDropDown
            app.SyncPreambleLengthDropDown = uidropdown(app.BlockSettingsTab);
            app.SyncPreambleLengthDropDown.Items = {'256', '512', '1024', '2048'};
            app.SyncPreambleLengthDropDown.ItemsData = {'256', '512', '1024', '2048'};
            app.SyncPreambleLengthDropDown.Position = [200 166 136 22];
            app.SyncPreambleLengthDropDown.Value = '1024';

            % Create DeviceSettingsTab
            app.DeviceSettingsTab = uitab(app.TabGroup);
            app.DeviceSettingsTab.Title = 'Device Settings';

            % Create ScopeDropDownLabel
            app.ScopeDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.ScopeDropDownLabel.Position = [19 276 43 22];
            app.ScopeDropDownLabel.Text = 'Scope:';

            % Create ScopeDropDown
            app.ScopeDropDown = uidropdown(app.DeviceSettingsTab);
            app.ScopeDropDown.Items = {};
            app.ScopeDropDown.Position = [77 276 304 22];
            app.ScopeDropDown.Value = {};

            % Create AWGDropDownLabel
            app.AWGDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.AWGDropDownLabel.Position = [19 195 34 22];
            app.AWGDropDownLabel.Text = 'AWG:';

            % Create AWGDropDown
            app.AWGDropDown = uidropdown(app.DeviceSettingsTab);
            app.AWGDropDown.Items = {};
            app.AWGDropDown.Position = [77 195 304 22];
            app.AWGDropDown.Value = {};

            % Create RefreshDeviceListButton
            app.RefreshDeviceListButton = uibutton(app.DeviceSettingsTab, 'push');
            app.RefreshDeviceListButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshDeviceListButtonPushed, true);
            app.RefreshDeviceListButton.Position = [138 125 120 22];
            app.RefreshDeviceListButton.Text = 'Refresh Device List';

            % Create RefreshLamp
            app.RefreshLamp = uilamp(app.DeviceSettingsTab);
            app.RefreshLamp.Position = [361 29 20 20];

            % Create EnableSimulatorModeCheckBox
            app.EnableSimulatorModeCheckBox = uicheckbox(app.DeviceSettingsTab);
            app.EnableSimulatorModeCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableSimulatorModeCheckBoxValueChanged, true);
            app.EnableSimulatorModeCheckBox.Text = 'Enable Simulator Mode';
            app.EnableSimulatorModeCheckBox.Position = [126 28 147 22];

            % Show the figure after all components are created
            app.MQAMSystemv05UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = mqamApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.MQAMSystemv05UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.MQAMSystemv05UIFigure)
        end
    end
end