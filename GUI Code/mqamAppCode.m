classdef mqamApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        MQAMSystemv05UIFigure          matlab.ui.Figure
        TabGroup                       matlab.ui.container.TabGroup
        MQAMTab                        matlab.ui.container.Tab
        SendButton                     matlab.ui.control.StateButton
        ReadButton                     matlab.ui.control.StateButton
        MQAMDropDownLabel              matlab.ui.control.Label
        MQAMDropDown                   matlab.ui.control.DropDown
        FrameLengthsymbolsEditFieldLabel  matlab.ui.control.Label
        FrameLengthsymbolsEditField    matlab.ui.control.NumericEditField
        RandomSeedEditFieldLabel       matlab.ui.control.Label
        RandomSeedEditField            matlab.ui.control.NumericEditField
        SymbolRatesymssecEditFieldLabel  matlab.ui.control.Label
        SymbolRatesymssecEditField     matlab.ui.control.NumericEditField
        ApplyTxCalibrationSwitchLabel  matlab.ui.control.Label
        ApplyTxCalibrationSwitch       matlab.ui.control.ToggleSwitch
        ApplyRxCalibrationSwitchLabel  matlab.ui.control.Label
        ApplyRxCalibrationSwitch       matlab.ui.control.ToggleSwitch
        Status                         matlab.ui.control.Label
        ForwardErrorCorrectionButtonGroup  matlab.ui.container.ButtonGroup
        NoneButton                     matlab.ui.control.RadioButton
        ConvolutionalButton            matlab.ui.control.RadioButton
        LDPCButton                     matlab.ui.control.RadioButton
        RateDropDown                   matlab.ui.control.DropDown
        LDPCBlockLengthDropDown        matlab.ui.control.DropDown
        LDPCBlockLengthDropDownLabel   matlab.ui.control.Label
        RateDropDownLabel              matlab.ui.control.Label
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
        
        function dataBlock = buildDataBlock(app)
            
            selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
            
            M = str2num(app.MQAMDropDown.Value);
            N_syms = app.FrameLengthsymbolsEditField.Value;
            rng_seed = app.RandomSeedEditField.Value;
            
            switch selectedButton.Text
                case 'None' % No channel coding
                    rng(rng_seed);          % Random Seed
                    dataBlock = randi([0 1],log2(M)*N_syms,1);
                case 'Convolutional'
                    % Convolutional Coding
                    rng(rng_seed);          % Random Seed
                    dataBlock = randi([0 1],log2(M)*N_syms,1);
                    rate = str2num(app.RateDropDown.Value);
                    dataBlock = convEncode(dataBlock,rate);
                case 'LDPC'
                    blockLen = str2num(app.LDPCBlockLengthDropDown.Value);
                    rate = str2num(app.RateDropDown.Value);
                    dataBlock = ldpcEncode(blockLen,rate,rng_seed);
                otherwise
                    rng(rng_seed);          % Random Seed
                    dataBlock = randi([0 1],log2(M)*N_syms,1);
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
            txObj.Nsyms = app.FrameLengthsymbolsEditField.Value;
            txObj.data = buildDataBlock(app);
            txObj.txCal = TX_CAL;
            txObj.M = str2num(app.MQAMDropDown.Value);
            
            try
                buildMQAM(txObj,2,AWGVisaType,AWGVisaAddr);
                app.Status.FontColor = [0.47 0.67 0.19];
                app.Status.Text = 'Send Successful.';
            catch ME
                warning('Error Running buildMQAM');
                warning(ME.message);
                app.Status.Text = 'An Error Occured';
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
            txObj.Nsyms = app.FrameLengthsymbolsEditField.Value;
            txObj.data = buildDataBlock(app);
            txObj.rxCal = RX_CAL;
            txObj.M = str2num(app.MQAMDropDown.Value);
            
            % Load Coding Scheme into Tx Object
            switch selectedButton.Text
                case 'None' % No channel coding
                    txObj.coding = 0;
                case 'Convolutional'
                    txObj.coding = 1;
                    txObj.rate = str2num(app.RateDropDown.Value); 
                case 'LDPC'
                    txObj.blockLen = str2num(app.LDPCBlockLengthDropDown.Value);
                    txObj.rate = str2num(app.RateDropDown.Value);       
                    txObj.coding = 2;
                otherwise
            end
                    
                    try
                        readMQAM(txObj,DSOVisaType,DSOVisaAddr);
                        app.Status.FontColor = [0.47 0.67 0.19];
                        app.Status.Text = 'Read Successful.';
                    catch ME
                        warning('Error Running readMQAM');
                        warning(ME.message);
                        app.Status.Text = 'An Error Occured';
                        app.Status.FontColor = [0.64 0.08 0.18];
                    end
                    
                    app.ReadButton.Value = 0;
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
                    app.Status.FontColor = [0.47 0.67 0.19];
                    app.Status.Text = 'Entered Simulator Mode.';
                else
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
                        app.FrameLengthsymbolsEditField.Enable = 1;
                    case 'Convolutional'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.LDPCBlockLengthDropDown.Visible = 0;
                        app.LDPCBlockLengthDropDownLabel.Visible = 0;
                        app.FrameLengthsymbolsEditField.Enable = 1;
                    case 'LDPC'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.LDPCBlockLengthDropDown.Visible = 1;
                        app.LDPCBlockLengthDropDownLabel.Visible = 1;
                        app.FrameLengthsymbolsEditField.Enable = 0;
                    otherwise
                        app.RateDropDown.Visible = 0;
                        app.LDPCBlockLengthDropDown.Visible = 0;
                end
                
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create MQAMSystemv05UIFigure
            app.MQAMSystemv05UIFigure = uifigure;
            app.MQAMSystemv05UIFigure.Position = [100 100 396 464];
            app.MQAMSystemv05UIFigure.Name = 'M-QAM System - v0.5';
            app.MQAMSystemv05UIFigure.Resize = 'off';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.MQAMSystemv05UIFigure);
            app.TabGroup.Position = [1 -4 397 469];

            % Create MQAMTab
            app.MQAMTab = uitab(app.TabGroup);
            app.MQAMTab.Title = 'M-QAM';

            % Create SendButton
            app.SendButton = uibutton(app.MQAMTab, 'state');
            app.SendButton.ValueChangedFcn = createCallbackFcn(app, @SendButtonValueChanged, true);
            app.SendButton.Text = 'Send';
            app.SendButton.Position = [67 56 100 22];

            % Create ReadButton
            app.ReadButton = uibutton(app.MQAMTab, 'state');
            app.ReadButton.ValueChangedFcn = createCallbackFcn(app, @ReadButtonValueChanged, true);
            app.ReadButton.Text = 'Read';
            app.ReadButton.Position = [238 56 100 22];

            % Create MQAMDropDownLabel
            app.MQAMDropDownLabel = uilabel(app.MQAMTab);
            app.MQAMDropDownLabel.Position = [60 397 47 22];
            app.MQAMDropDownLabel.Text = 'M-QAM';

            % Create MQAMDropDown
            app.MQAMDropDown = uidropdown(app.MQAMTab);
            app.MQAMDropDown.Items = {'4', '16', '32', '64', '128', '256', '512', '1024'};
            app.MQAMDropDown.Editable = 'on';
            app.MQAMDropDown.BackgroundColor = [1 1 1];
            app.MQAMDropDown.Position = [194 397 144 22];
            app.MQAMDropDown.Value = '4';

            % Create FrameLengthsymbolsEditFieldLabel
            app.FrameLengthsymbolsEditFieldLabel = uilabel(app.MQAMTab);
            app.FrameLengthsymbolsEditFieldLabel.Position = [60 328 136 22];
            app.FrameLengthsymbolsEditFieldLabel.Text = 'Frame Length (symbols)';

            % Create FrameLengthsymbolsEditField
            app.FrameLengthsymbolsEditField = uieditfield(app.MQAMTab, 'numeric');
            app.FrameLengthsymbolsEditField.Position = [238 328 100 22];
            app.FrameLengthsymbolsEditField.Value = 2000;

            % Create RandomSeedEditFieldLabel
            app.RandomSeedEditFieldLabel = uilabel(app.MQAMTab);
            app.RandomSeedEditFieldLabel.Position = [58 292 82 22];
            app.RandomSeedEditFieldLabel.Text = 'Random Seed';

            % Create RandomSeedEditField
            app.RandomSeedEditField = uieditfield(app.MQAMTab, 'numeric');
            app.RandomSeedEditField.Position = [238 292 100 22];
            app.RandomSeedEditField.Value = 2369;

            % Create SymbolRatesymssecEditFieldLabel
            app.SymbolRatesymssecEditFieldLabel = uilabel(app.MQAMTab);
            app.SymbolRatesymssecEditFieldLabel.Position = [60 361 136 22];
            app.SymbolRatesymssecEditFieldLabel.Text = 'Symbol Rate (syms/sec)';

            % Create SymbolRatesymssecEditField
            app.SymbolRatesymssecEditField = uieditfield(app.MQAMTab, 'numeric');
            app.SymbolRatesymssecEditField.Position = [238 361 100 22];
            app.SymbolRatesymssecEditField.Value = 1000;

            % Create ApplyTxCalibrationSwitchLabel
            app.ApplyTxCalibrationSwitchLabel = uilabel(app.MQAMTab);
            app.ApplyTxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyTxCalibrationSwitchLabel.Position = [60 252 113 22];
            app.ApplyTxCalibrationSwitchLabel.Text = 'Apply Tx Calibration';

            % Create ApplyTxCalibrationSwitch
            app.ApplyTxCalibrationSwitch = uiswitch(app.MQAMTab, 'toggle');
            app.ApplyTxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyTxCalibrationSwitch.Position = [99 228 38 16];
            app.ApplyTxCalibrationSwitch.Value = 'On';

            % Create ApplyRxCalibrationSwitchLabel
            app.ApplyRxCalibrationSwitchLabel = uilabel(app.MQAMTab);
            app.ApplyRxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyRxCalibrationSwitchLabel.Position = [228 252 118 22];
            app.ApplyRxCalibrationSwitchLabel.Text = ' Apply Rx Calibration';

            % Create ApplyRxCalibrationSwitch
            app.ApplyRxCalibrationSwitch = uiswitch(app.MQAMTab, 'toggle');
            app.ApplyRxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyRxCalibrationSwitch.Position = [268 229 38 16];
            app.ApplyRxCalibrationSwitch.Value = 'On';

            % Create Status
            app.Status = uilabel(app.MQAMTab);
            app.Status.HorizontalAlignment = 'center';
            app.Status.Position = [48 22 302 22];
            app.Status.Text = '';

            % Create ForwardErrorCorrectionButtonGroup
            app.ForwardErrorCorrectionButtonGroup = uibuttongroup(app.MQAMTab);
            app.ForwardErrorCorrectionButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ForwardErrorCorrectionButtonGroupSelectionChanged, true);
            app.ForwardErrorCorrectionButtonGroup.Title = 'Forward Error Correction';
            app.ForwardErrorCorrectionButtonGroup.Position = [30 95 338 106];

            % Create NoneButton
            app.NoneButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.NoneButton.Text = 'None';
            app.NoneButton.Position = [11 60 58 22];
            app.NoneButton.Value = true;

            % Create ConvolutionalButton
            app.ConvolutionalButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.ConvolutionalButton.Text = 'Convolutional';
            app.ConvolutionalButton.Position = [11 38 95 22];

            % Create LDPCButton
            app.LDPCButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCButton.Text = 'LDPC';
            app.LDPCButton.Position = [11 16 65 22];

            % Create RateDropDown
            app.RateDropDown = uidropdown(app.ForwardErrorCorrectionButtonGroup);
            app.RateDropDown.Items = {'1/2', '2/3', '3/4', '5/6'};
            app.RateDropDown.ItemsData = {'1', '2', '3', '4'};
            app.RateDropDown.Position = [226 59 100 22];
            app.RateDropDown.Value = '1';

            % Create LDPCBlockLengthDropDown
            app.LDPCBlockLengthDropDown = uidropdown(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCBlockLengthDropDown.Items = {'648', '1296', '1944'};
            app.LDPCBlockLengthDropDown.ItemsData = {'648', '1296', '1944'};
            app.LDPCBlockLengthDropDown.Position = [226 17 100 22];
            app.LDPCBlockLengthDropDown.Value = '648';

            % Create LDPCBlockLengthDropDownLabel
            app.LDPCBlockLengthDropDownLabel = uilabel(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCBlockLengthDropDownLabel.HorizontalAlignment = 'right';
            app.LDPCBlockLengthDropDownLabel.Position = [142 16 75 22];
            app.LDPCBlockLengthDropDownLabel.Text = 'Block Length';

            % Create RateDropDownLabel
            app.RateDropDownLabel = uilabel(app.ForwardErrorCorrectionButtonGroup);
            app.RateDropDownLabel.HorizontalAlignment = 'right';
            app.RateDropDownLabel.Position = [180 59 31 22];
            app.RateDropDownLabel.Text = 'Rate';

            % Create DeviceSettingsTab
            app.DeviceSettingsTab = uitab(app.TabGroup);
            app.DeviceSettingsTab.Title = 'Device Settings';

            % Create ScopeDropDownLabel
            app.ScopeDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.ScopeDropDownLabel.Position = [19 366 43 22];
            app.ScopeDropDownLabel.Text = 'Scope:';

            % Create ScopeDropDown
            app.ScopeDropDown = uidropdown(app.DeviceSettingsTab);
            app.ScopeDropDown.Items = {};
            app.ScopeDropDown.Position = [77 366 304 22];
            app.ScopeDropDown.Value = {};

            % Create AWGDropDownLabel
            app.AWGDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.AWGDropDownLabel.Position = [19 285 34 22];
            app.AWGDropDownLabel.Text = 'AWG:';

            % Create AWGDropDown
            app.AWGDropDown = uidropdown(app.DeviceSettingsTab);
            app.AWGDropDown.Items = {};
            app.AWGDropDown.Position = [77 285 304 22];
            app.AWGDropDown.Value = {};

            % Create RefreshDeviceListButton
            app.RefreshDeviceListButton = uibutton(app.DeviceSettingsTab, 'push');
            app.RefreshDeviceListButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshDeviceListButtonPushed, true);
            app.RefreshDeviceListButton.Position = [138 90 120 22];
            app.RefreshDeviceListButton.Text = 'Refresh Device List';

            % Create RefreshLamp
            app.RefreshLamp = uilamp(app.DeviceSettingsTab);
            app.RefreshLamp.Position = [361 91 20 20];

            % Create EnableSimulatorModeCheckBox
            app.EnableSimulatorModeCheckBox = uicheckbox(app.DeviceSettingsTab);
            app.EnableSimulatorModeCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableSimulatorModeCheckBoxValueChanged, true);
            app.EnableSimulatorModeCheckBox.Text = 'Enable Simulator Mode';
            app.EnableSimulatorModeCheckBox.Position = [126 19 147 22];
        end
    end

    methods (Access = public)

        % Construct app
        function app = mqamApp

            % Create and configure components
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