classdef mqamApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        MQAMSystemv075UIFigure          matlab.ui.Figure
        TabGroup                        matlab.ui.container.TabGroup
        TxRxTab                         matlab.ui.container.Tab
        TransmitButton                  matlab.ui.control.StateButton
        ReceiveButton                   matlab.ui.control.StateButton
        QAMOrderDropDownLabel           matlab.ui.control.Label
        QAMOrderDropDown                matlab.ui.control.DropDown
        Status                          matlab.ui.control.Label
        ForwardErrorCorrectionButtonGroup  matlab.ui.container.ButtonGroup
        NoneButton                      matlab.ui.control.RadioButton
        ConvolutionalButton             matlab.ui.control.RadioButton
        LDPCButton                      matlab.ui.control.RadioButton
        RateDropDown                    matlab.ui.control.DropDown
        RateDropDownLabel               matlab.ui.control.Label
        TurboButton                     matlab.ui.control.RadioButton
        DataRateLabel                   matlab.ui.control.Label
        DataRateTxt                     matlab.ui.control.Label
        BlockLengthDropDown             matlab.ui.control.DropDown
        BlockLengthDropDownLabel        matlab.ui.control.Label
        ofBlocksDropDownLabel           matlab.ui.control.Label
        ofBlocksDropDown                matlab.ui.control.DropDown
        BlockSettingsTab                matlab.ui.container.Tab
        SymbolRatesymssecEditFieldLabel  matlab.ui.control.Label
        SymbolRatesymssecEditField      matlab.ui.control.NumericEditField
        ApplyTxCalibrationSwitchLabel   matlab.ui.control.Label
        ApplyTxCalibrationSwitch        matlab.ui.control.ToggleSwitch
        ApplyRxCalibrationSwitchLabel   matlab.ui.control.Label
        ApplyRxCalibrationSwitch        matlab.ui.control.ToggleSwitch
        SyncPreambleLengthDropDownLabel  matlab.ui.control.Label
        SyncPreambleLengthDropDown      matlab.ui.control.DropDown
        RandomDataSeedDropDownLabel     matlab.ui.control.Label
        RandomDataSeedDropDown          matlab.ui.control.DropDown
        DecodeIterationsEditFieldLabel  matlab.ui.control.Label
        DecodeIterationsEditField       matlab.ui.control.NumericEditField
        RFCalibrationTab                matlab.ui.container.Tab
        RunTxCalibrationButton          matlab.ui.control.StateButton
        AnalogRxFilterTuningButton      matlab.ui.control.StateButton
        RunRxCalibrationButton          matlab.ui.control.StateButton
        DeviceSettingsTab               matlab.ui.container.Tab
        ScopeDropDownLabel              matlab.ui.control.Label
        ScopeDropDown                   matlab.ui.control.DropDown
        AWGDropDownLabel                matlab.ui.control.Label
        AWGDropDown                     matlab.ui.control.DropDown
        RefreshDeviceListButton         matlab.ui.control.Button
        RefreshLamp                     matlab.ui.control.Lamp
        EnableSimulatorModeCheckBox     matlab.ui.control.CheckBox
        SimulatedAWGNSNREditFieldLabel  matlab.ui.control.Label
        SimulatedAWGNSNREditField       matlab.ui.control.NumericEditField
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
            app.TransmitButton.Enable = 0;
            app.ReceiveButton.Enable = 0;
            % Disable Calibration Function Buttons
            app.RunRxCalibrationButton.Enable = 0;
            app.RunTxCalibrationButton.Enable = 0;
            app.AnalogRxFilterTuningButton.Enable = 0;
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
                %                 app.TransmitButton.Enable = 0;
                %                 app.ReceiveButton.Enable = 0;
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
                app.TransmitButton.Enable = 1;
                app.ReceiveButton.Enable = 1;
                app.Status.Text = '';
                
                % Enable Calibration Function Buttons
                app.RunRxCalibrationButton.Enable = 1;
                app.RunTxCalibrationButton.Enable = 1;
                app.AnalogRxFilterTuningButton.Enable = 1;

                % Device refresh successful, set lamp to green
                app.RefreshLamp.Color = 'Green';
            end
            
        end
        
        function [encBlock, dataBits] = buildencBlock(app)
            
            selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
            
            M = str2num(app.QAMOrderDropDown.Value);
            rng_seed = str2num(app.RandomDataSeedDropDown.Value);
            blockLen = str2num(app.BlockLengthDropDown.Value);
            switch selectedButton.Text
                case 'None' % No channel coding
                    rng(rng_seed);          % Random Seed
                    dataBits = randi([0 1],blockLen,1);
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
                    
                    NdataBits = blockLen*r;
                    rng(rng_seed);          % Random Seed
                    dataBits = randi([0 1],NdataBits,1);
                    % Tail bits to flush the encoder
                    dataBits(end-31:end) = zeros(32,1);
                    encBlock = convEncode(dataBits,rate);

                        
                case 'LDPC'
                    rate = str2num(app.RateDropDown.Value);
                    [encBlock, dataBits] = ldpcEncode(blockLen,rate,rng_seed);
                case 'Turbo'
                    [encBlock, dataBits] = turbEncode((blockLen-12)/3,rng_seed);
                otherwise
                    rng(rng_seed);          % Random Seed
                    dataBits = randi([0 1],blockLen,1);
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
        
        function [] = calcDataRate(app)
            symRate = app.SymbolRatesymssecEditField.Value;
            bpSym = log2(str2num(app.QAMOrderDropDown.Value));
            
            selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
                
                switch selectedButton.Text
                    case 'None'
                        codeRate = 1;
                    otherwise
                        ratesVec = [1/2 2/3 3/4 5/6 1/3];
                        codeRate = ratesVec(str2num(app.RateDropDown.Value));
                end
                

            dataRate = symRate*bpSym*codeRate;
            
            app.DataRateTxt.Text = [num2str(dataRate), ' bit/s'];
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
            app.BlockLengthDropDown.Visible = 1;
            app.BlockLengthDropDownLabel.Visible = 1;
            app.BlockLengthDropDown.Editable = 1;
            
            % Set Lamp
            app.RefreshLamp.Color = 'Yellow';
            refreshDevices(app);
            
            calcDataRate(app);
        end

        % Value changed function: TransmitButton
        function TransmitButtonValueChanged(app, event)
            
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
            txObj.itrs = app.DecodeIterationsEditField.Value;
            
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
            app.TransmitButton.Value = 0;
            
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv075UIFigure.Visible = 0;
            app.MQAMSystemv075UIFigure.Visible = 1;
            
        end

        % Value changed function: ReceiveButton
        function ReceiveButtonValueChanged(app, event)
            
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
            rxObj.Fsym = app.SymbolRatesymssecEditField.Value;
            rxObj.rxCal = RX_CAL;
            rxObj.M = str2num(app.QAMOrderDropDown.Value);
            rxObj.itrs = app.DecodeIterationsEditField.Value;
            rxObj.readItrs = str2num(app.ofBlocksDropDown.Value);
            rxObj.awgnSNR = app.SimulatedAWGNSNREditField.Value;

            
            % Load Preamble Length, Set M-seq order and taps
            switch str2num(app.SyncPreambleLengthDropDown.Value)
                case 256
                    rxObj.preM = 8;
                    rxObj.preTaps = [8, 6, 5, 4];
                case 512
                    rxObj.preM = 9;
                    rxObj.preTaps = [9, 8, 6, 5];
                case 1024
                    rxObj.preM = 10;
                    rxObj.preTaps = [10, 9, 7, 6];
                case 2048
                    rxObj.preM = 11;
                    rxObj.preTaps = [11, 10, 9, 7];
                otherwise
                    rxObj.preM = 10;
                    rxObj.preTaps = [10, 9, 7, 6];
            end
            
            
            [encBlock, dataBits] = buildencBlock(app);
            rxObj.encBits = encBlock;
            rxObj.dataBits = dataBits;
            ratesVec = [1/2 2/3 3/4 5/6 1/3];
            
            % Load Coding Scheme into Tx Object
            selectedButton = app.ForwardErrorCorrectionButtonGroup.SelectedObject;
            switch selectedButton.Text
                case 'None' % No channel coding
                    rxObj.coding = 0;
                    rxObj.Nsyms = ceil(str2num(app.BlockLengthDropDown.Value)/(log2(rxObj.M)));
                case 'Convolutional'
                    rxObj.coding = 1;
                    rxObj.rate = str2num(app.RateDropDown.Value);
                    rxObj.Nsyms = ceil(str2num(app.BlockLengthDropDown.Value)/(log2(rxObj.M)));
                case 'LDPC'
                    rxObj.blockLen = str2num(app.BlockLengthDropDown.Value);
                    rxObj.rate = str2num(app.RateDropDown.Value);
                    rxObj.coding = 2;
                    rxObj.Nsyms = ceil(str2num(app.BlockLengthDropDown.Value)/(log2(rxObj.M)));
                case 'Turbo'
                    rxObj.coding = 3;
                    rxObj.rate = str2num(app.RateDropDown.Value);
                    rxObj.Nsyms = ceil(str2num(app.BlockLengthDropDown.Value)/(log2(rxObj.M)));
                    rxObj.itrs = app.DecodeIterationsEditField.Value;
                otherwise
            end
                             
                    try
                        readMQAM(rxObj,DSOVisaType,DSOVisaAddr);
                        app.Status.FontColor = [0.47 0.67 0.19];
                        app.Status.Text = 'Read Successful.';
                    catch ME
                        warning('Error Running readMQAM');
                        warning(ME.message);
                        app.Status.Text = 'An Error Occured. Check Command Window for details.';
                        app.Status.FontColor = [0.64 0.08 0.18];
                    end
                    
                    app.ReceiveButton.Value = 0;
                    
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv075UIFigure.Visible = 0;
            app.MQAMSystemv075UIFigure.Visible = 1;
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
                    % Enable Tx/Rx Function Buttons
                    app.TransmitButton.Enable = 1;
                    app.ReceiveButton.Enable = 1;
                    % Turn off apply calibration
                    app.ApplyRxCalibrationSwitch.Value = 'Off';
                    app.ApplyTxCalibrationSwitch.Value = 'Off';
                    app.Status.FontColor = [0.47 0.67 0.19];
%                     % Enable Calibration Function Buttons
%                     app.RunRxCalibrationButton.Enable = 1;
%                     app.RunTxCalibrationButton.Enable = 1;
%                     app.AnalogRxFilterTuningButton.Enable = 1;
                    % Update Status
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
                
                % Default Dropdown
                app.RateDropDown.Items = {'1/2','2/3','3/4','5/6'};
                app.RateDropDown.ItemsData = {'1', '2', '3', '4'};
                switch selectedButton.Text
                    case 'None'
                        app.RateDropDown.Visible = 0;
                        app.RateDropDownLabel.Visible = 0;
                        app.BlockLengthDropDown.Editable = 1;
                    case 'Convolutional'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.BlockLengthDropDown.Editable = 1;
                    case 'LDPC'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.BlockLengthDropDown.Editable = 0;
                    case 'Turbo'
                        app.RateDropDown.Visible = 1;
                        app.RateDropDownLabel.Visible = 1;
                        app.BlockLengthDropDown.Editable = 1;
                        app.RateDropDown.Editable = 0;
                        app.RateDropDown.Items = {'1/3'};
                        app.RateDropDown.ItemsData = {'5'};
                    otherwise
                        app.RateDropDown.Visible = 0;
                end
                
                calcDataRate(app);
                
        end

        % Value changed function: QAMOrderDropDown
        function QAMOrderDropDownValueChanged(app, event)

            calcDataRate(app);
        end

        % Value changed function: RateDropDown
        function RateDropDownValueChanged(app, event)
            calcDataRate(app);
            
        end

        % Value changed function: BlockLengthDropDown
        function BlockLengthDropDownValueChanged(app, event)
            calcDataRate(app);
        end

        % Value changed function: RunTxCalibrationButton
        function RunTxCalibrationButtonValueChanged(app, event)

            DSOVisa = app.ScopeDropDown.Value;
            DSOVisaType = DSOVisa.type;
            DSOVisaAddr = DSOVisa.addr;
            
            AWGVisa = app.AWGDropDown.Value;
            AWGVisaType = AWGVisa.type;
            AWGVisaAddr = AWGVisa.addr;
            
            app.Status.Text = 'Running Tx Calibration';
            app.Status.FontColor = 'Black';
            try
                readTxCal(DSOVisaType,DSOVisaAddr,AWGVisaType,AWGVisaAddr)
                app.Status.Text = 'Tx Calibration Successful';
                app.Status.FontColor = [0.47 0.67 0.19];
            catch ME
                warning('Error Running readTxCal');
                warning(ME.message);
                app.Status.Text = 'An Error Occured During Tx Calibration';
                app.Status.FontColor = [0.64 0.08 0.18];
            end
            app.RunTxCalibrationButton.Value = 0;
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv075UIFigure.Visible = 0;
            app.MQAMSystemv075UIFigure.Visible = 1;
        end

        % Value changed function: RunRxCalibrationButton
        function RunRxCalibrationButtonValueChanged(app, event)
            
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
            
            DSOVisa = app.ScopeDropDown.Value;
            DSOVisaType = DSOVisa.type;
            DSOVisaAddr = DSOVisa.addr;
            
            AWGVisa = app.AWGDropDown.Value;
            AWGVisaType = AWGVisa.type;
            AWGVisaAddr = AWGVisa.addr;
            
            app.Status.Text = 'Running Rx Calibration';
            app.Status.FontColor = 'Black';
            
            try
                readRxCal(DSOVisaType,DSOVisaAddr,AWGVisaType,AWGVisaAddr)
                app.Status.Text = 'Rx Calibration Successful';
                app.Status.FontColor = [0.47 0.67 0.19];
            catch ME
                warning('Error Running readRxCal');
                warning(ME.message);
                app.Status.Text = 'An Error Occured During Rx Calibration';
                app.Status.FontColor = [0.64 0.08 0.18];
            end
            
            app.RunRxCalibrationButton.Value = 0;
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv075UIFigure.Visible = 0;
            app.MQAMSystemv075UIFigure.Visible = 1;
        end

        % Value changed function: AnalogRxFilterTuningButton
        function AnalogRxFilterTuningButtonValueChanged(app, event)
            
            
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
            if ~SIM_MODE
                
                DSOVisa = app.ScopeDropDown.Value;
                DSOVisaType = DSOVisa.type;
                DSOVisaAddr = DSOVisa.addr;
            
                AWGVisa = app.AWGDropDown.Value;
                AWGVisaType = AWGVisa.type;
                AWGVisaAddr = AWGVisa.addr;
            
                
                app.Status.Text = 'Setting Up Filter Calibration';
                app.Status.FontColor = 'Black';
                try
                    
                    % Send Pulse to AWG
                    buildFiltCal(AWGVisaType,AWGVisaAddr);
                    % Set Rigol to Filter Viewing mode
                    setDSO(4,[],[],DSOVisaType,DSOVisaAddr);
                    
                    app.Status.Text = 'DSO Set Successful';
                    app.Status.FontColor = [0.47 0.67 0.19];
                    
                    
                    % PLot Examples
                    if isfile('Data Files\filter_tuned.mat') && isfile('Data Files\filter_untuned.mat')

                        a = load('Data Files\filter_untuned.mat');
                        figure;
                        plot(a.tq,a.F1rx,a.tq,a.F2rx);
                        grid on; grid minor;
                        legend('Filter One','Filter Two');
                        title('Example of an Untuned Filter Response (Not Live Data)');
                        
                        a = load('Data Files\filter_tuned.mat');
                        figure
                        plot(a.tq,a.F1rx,a.tq,a.F2rx);
                        grid on; grid minor;
                        legend('Filter One','Filter Two');
                        title('Example of a Tuned Filter Response (Not Live Data)');
                        
                    end
                    
                    
                    
                catch ME
                    warning('Error Running setRigol');
                    warning(ME.message);
                    app.Status.Text = 'An Error Occured';
                    app.Status.FontColor = [0.64 0.08 0.18];
                end
            else
                
                % PLot Examples
                if isfile('Data Files\filter_tuned.mat') && isfile('Data Files\filter_untuned.mat')
                    disp('try plots');
                    a = load('Data Files\filter_untuned.mat');
                    figure;
                    plot(a.tq,a.F1rx,a.tq,a.F2rx);
                    grid on; grid minor;
                    legend('Filter One','Filter Two');
                    title('Example of an Untuned Filter Response');
                    
                    a = load('Data Files\filter_tuned.mat');
                    figure
                    plot(a.tq,a.F1rx,a.tq,a.F2rx);
                    grid on; grid minor;
                    legend('Filter One','Filter Two');
                    title('Example of a tuned Filter Response');
                    
                end
            end
            
            app.AnalogRxFilterTuningButton.Value = 0;
            % Disable/Enable visablity to bring app window back to the foreground
            app.MQAMSystemv075UIFigure.Visible = 0;
            app.MQAMSystemv075UIFigure.Visible = 1;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create MQAMSystemv075UIFigure and hide until all components are created
            app.MQAMSystemv075UIFigure = uifigure('Visible', 'off');
            app.MQAMSystemv075UIFigure.Position = [100 100 780 651];
            app.MQAMSystemv075UIFigure.Name = 'M-QAM System - v0.75';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.MQAMSystemv075UIFigure);
            app.TabGroup.Position = [1 0 783 652];

            % Create TxRxTab
            app.TxRxTab = uitab(app.TabGroup);
            app.TxRxTab.Title = 'Tx/Rx';

            % Create TransmitButton
            app.TransmitButton = uibutton(app.TxRxTab, 'state');
            app.TransmitButton.ValueChangedFcn = createCallbackFcn(app, @TransmitButtonValueChanged, true);
            app.TransmitButton.Text = 'Transmit';
            app.TransmitButton.FontSize = 30;
            app.TransmitButton.Position = [95 57 131 43];

            % Create ReceiveButton
            app.ReceiveButton = uibutton(app.TxRxTab, 'state');
            app.ReceiveButton.ValueChangedFcn = createCallbackFcn(app, @ReceiveButtonValueChanged, true);
            app.ReceiveButton.Text = 'Receive';
            app.ReceiveButton.FontSize = 30;
            app.ReceiveButton.Position = [330 57 124 43];

            % Create QAMOrderDropDownLabel
            app.QAMOrderDropDownLabel = uilabel(app.TxRxTab);
            app.QAMOrderDropDownLabel.FontSize = 30;
            app.QAMOrderDropDownLabel.Position = [43 561 159 36];
            app.QAMOrderDropDownLabel.Text = 'QAM Order';

            % Create QAMOrderDropDown
            app.QAMOrderDropDown = uidropdown(app.TxRxTab);
            app.QAMOrderDropDown.Items = {'4', '16', '32', '64', '128', '256', '512', '1024'};
            app.QAMOrderDropDown.Editable = 'on';
            app.QAMOrderDropDown.ValueChangedFcn = createCallbackFcn(app, @QAMOrderDropDownValueChanged, true);
            app.QAMOrderDropDown.FontSize = 30;
            app.QAMOrderDropDown.BackgroundColor = [1 1 1];
            app.QAMOrderDropDown.Position = [379 561 360 36];
            app.QAMOrderDropDown.Value = '4';

            % Create Status
            app.Status = uilabel(app.TxRxTab);
            app.Status.HorizontalAlignment = 'center';
            app.Status.FontSize = 30;
            app.Status.Position = [43 3 696 36];
            app.Status.Text = '';

            % Create ForwardErrorCorrectionButtonGroup
            app.ForwardErrorCorrectionButtonGroup = uibuttongroup(app.TxRxTab);
            app.ForwardErrorCorrectionButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ForwardErrorCorrectionButtonGroupSelectionChanged, true);
            app.ForwardErrorCorrectionButtonGroup.Title = 'Forward Error Correction';
            app.ForwardErrorCorrectionButtonGroup.FontSize = 30;
            app.ForwardErrorCorrectionButtonGroup.Position = [43 183 696 287];

            % Create NoneButton
            app.NoneButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.NoneButton.Text = 'None';
            app.NoneButton.FontSize = 30;
            app.NoneButton.Position = [14 198 94 34];
            app.NoneButton.Value = true;

            % Create ConvolutionalButton
            app.ConvolutionalButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.ConvolutionalButton.Text = 'Convolutional';
            app.ConvolutionalButton.FontSize = 30;
            app.ConvolutionalButton.Position = [14 142 205 34];

            % Create LDPCButton
            app.LDPCButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.LDPCButton.Text = 'LDPC';
            app.LDPCButton.FontSize = 30;
            app.LDPCButton.Position = [14 84 102 34];

            % Create RateDropDown
            app.RateDropDown = uidropdown(app.ForwardErrorCorrectionButtonGroup);
            app.RateDropDown.Items = {'1/2', '2/3', '3/4', '5/6'};
            app.RateDropDown.ItemsData = {'1', '2', '3', '4'};
            app.RateDropDown.ValueChangedFcn = createCallbackFcn(app, @RateDropDownValueChanged, true);
            app.RateDropDown.FontSize = 30;
            app.RateDropDown.Position = [524 107 100 36];
            app.RateDropDown.Value = '1';

            % Create RateDropDownLabel
            app.RateDropDownLabel = uilabel(app.ForwardErrorCorrectionButtonGroup);
            app.RateDropDownLabel.HorizontalAlignment = 'right';
            app.RateDropDownLabel.FontSize = 30;
            app.RateDropDownLabel.Position = [361 107 157 36];
            app.RateDropDownLabel.Text = 'Code Rate:';

            % Create TurboButton
            app.TurboButton = uiradiobutton(app.ForwardErrorCorrectionButtonGroup);
            app.TurboButton.Text = 'Turbo';
            app.TurboButton.FontSize = 30;
            app.TurboButton.Position = [14 23 99 34];

            % Create DataRateLabel
            app.DataRateLabel = uilabel(app.TxRxTab);
            app.DataRateLabel.FontSize = 30;
            app.DataRateLabel.Position = [43 124 149 36];
            app.DataRateLabel.Text = 'Data Rate:';

            % Create DataRateTxt
            app.DataRateTxt = uilabel(app.TxRxTab);
            app.DataRateTxt.FontSize = 30;
            app.DataRateTxt.Position = [205 124 534 36];
            app.DataRateTxt.Text = '';

            % Create BlockLengthDropDown
            app.BlockLengthDropDown = uidropdown(app.TxRxTab);
            app.BlockLengthDropDown.Items = {'648', '1296', '1944'};
            app.BlockLengthDropDown.ItemsData = {'648', '1296', '1944'};
            app.BlockLengthDropDown.ValueChangedFcn = createCallbackFcn(app, @BlockLengthDropDownValueChanged, true);
            app.BlockLengthDropDown.FontSize = 30;
            app.BlockLengthDropDown.Position = [608 500 131 36];
            app.BlockLengthDropDown.Value = '1944';

            % Create BlockLengthDropDownLabel
            app.BlockLengthDropDownLabel = uilabel(app.TxRxTab);
            app.BlockLengthDropDownLabel.FontSize = 30;
            app.BlockLengthDropDownLabel.Position = [43 500 331 36];
            app.BlockLengthDropDownLabel.Text = 'Total Block Length (bits)';

            % Create ofBlocksDropDownLabel
            app.ofBlocksDropDownLabel = uilabel(app.TxRxTab);
            app.ofBlocksDropDownLabel.FontSize = 25;
            app.ofBlocksDropDownLabel.Position = [521 63 135 31];
            app.ofBlocksDropDownLabel.Text = '# of Blocks:';

            % Create ofBlocksDropDown
            app.ofBlocksDropDown = uidropdown(app.TxRxTab);
            app.ofBlocksDropDown.Items = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10'};
            app.ofBlocksDropDown.Editable = 'on';
            app.ofBlocksDropDown.FontSize = 30;
            app.ofBlocksDropDown.BackgroundColor = [1 1 1];
            app.ofBlocksDropDown.Position = [664 58 64 36];
            app.ofBlocksDropDown.Value = '1';

            % Create BlockSettingsTab
            app.BlockSettingsTab = uitab(app.TabGroup);
            app.BlockSettingsTab.Title = 'Block Settings';

            % Create SymbolRatesymssecEditFieldLabel
            app.SymbolRatesymssecEditFieldLabel = uilabel(app.BlockSettingsTab);
            app.SymbolRatesymssecEditFieldLabel.FontSize = 30;
            app.SymbolRatesymssecEditFieldLabel.Position = [151 515 336 36];
            app.SymbolRatesymssecEditFieldLabel.Text = 'Symbol Rate (syms/sec)';

            % Create SymbolRatesymssecEditField
            app.SymbolRatesymssecEditField = uieditfield(app.BlockSettingsTab, 'numeric');
            app.SymbolRatesymssecEditField.FontSize = 30;
            app.SymbolRatesymssecEditField.Position = [517 515 100 36];
            app.SymbolRatesymssecEditField.Value = 1000;

            % Create ApplyTxCalibrationSwitchLabel
            app.ApplyTxCalibrationSwitchLabel = uilabel(app.BlockSettingsTab);
            app.ApplyTxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyTxCalibrationSwitchLabel.FontSize = 28;
            app.ApplyTxCalibrationSwitchLabel.Position = [118 128 259 34];
            app.ApplyTxCalibrationSwitchLabel.Text = 'Apply Tx Calibration';

            % Create ApplyTxCalibrationSwitch
            app.ApplyTxCalibrationSwitch = uiswitch(app.BlockSettingsTab, 'toggle');
            app.ApplyTxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyTxCalibrationSwitch.FontSize = 30;
            app.ApplyTxCalibrationSwitch.Position = [229 83 38 16];
            app.ApplyTxCalibrationSwitch.Value = 'On';

            % Create ApplyRxCalibrationSwitchLabel
            app.ApplyRxCalibrationSwitchLabel = uilabel(app.BlockSettingsTab);
            app.ApplyRxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyRxCalibrationSwitchLabel.FontSize = 28;
            app.ApplyRxCalibrationSwitchLabel.Position = [389 128 270 34];
            app.ApplyRxCalibrationSwitchLabel.Text = ' Apply Rx Calibration';

            % Create ApplyRxCalibrationSwitch
            app.ApplyRxCalibrationSwitch = uiswitch(app.BlockSettingsTab, 'toggle');
            app.ApplyRxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyRxCalibrationSwitch.FontSize = 30;
            app.ApplyRxCalibrationSwitch.Position = [502 83 38 16];
            app.ApplyRxCalibrationSwitch.Value = 'On';

            % Create SyncPreambleLengthDropDownLabel
            app.SyncPreambleLengthDropDownLabel = uilabel(app.BlockSettingsTab);
            app.SyncPreambleLengthDropDownLabel.FontSize = 30;
            app.SyncPreambleLengthDropDownLabel.Position = [152 433 313 36];
            app.SyncPreambleLengthDropDownLabel.Text = 'Sync Preamble Length';

            % Create SyncPreambleLengthDropDown
            app.SyncPreambleLengthDropDown = uidropdown(app.BlockSettingsTab);
            app.SyncPreambleLengthDropDown.Items = {'256', '512', '1024', '2048'};
            app.SyncPreambleLengthDropDown.ItemsData = {'256', '512', '1024', '2048'};
            app.SyncPreambleLengthDropDown.FontSize = 30;
            app.SyncPreambleLengthDropDown.Position = [480 433 136 36];
            app.SyncPreambleLengthDropDown.Value = '1024';

            % Create RandomDataSeedDropDownLabel
            app.RandomDataSeedDropDownLabel = uilabel(app.BlockSettingsTab);
            app.RandomDataSeedDropDownLabel.FontSize = 30;
            app.RandomDataSeedDropDownLabel.Position = [154 353 272 36];
            app.RandomDataSeedDropDownLabel.Text = 'Random Data Seed';

            % Create RandomDataSeedDropDown
            app.RandomDataSeedDropDown = uidropdown(app.BlockSettingsTab);
            app.RandomDataSeedDropDown.Items = {'A', 'B', 'C'};
            app.RandomDataSeedDropDown.ItemsData = {'32164', '12345', '88888'};
            app.RandomDataSeedDropDown.FontSize = 30;
            app.RandomDataSeedDropDown.Position = [482 353 136 36];
            app.RandomDataSeedDropDown.Value = '32164';

            % Create DecodeIterationsEditFieldLabel
            app.DecodeIterationsEditFieldLabel = uilabel(app.BlockSettingsTab);
            app.DecodeIterationsEditFieldLabel.FontSize = 30;
            app.DecodeIterationsEditFieldLabel.Position = [154 273 243 36];
            app.DecodeIterationsEditFieldLabel.Text = 'Decode Iterations';

            % Create DecodeIterationsEditField
            app.DecodeIterationsEditField = uieditfield(app.BlockSettingsTab, 'numeric');
            app.DecodeIterationsEditField.FontSize = 30;
            app.DecodeIterationsEditField.Position = [518 273 100 36];
            app.DecodeIterationsEditField.Value = 15;

            % Create RFCalibrationTab
            app.RFCalibrationTab = uitab(app.TabGroup);
            app.RFCalibrationTab.Title = 'RF Calibration';

            % Create RunTxCalibrationButton
            app.RunTxCalibrationButton = uibutton(app.RFCalibrationTab, 'state');
            app.RunTxCalibrationButton.ValueChangedFcn = createCallbackFcn(app, @RunTxCalibrationButtonValueChanged, true);
            app.RunTxCalibrationButton.Text = 'Run Tx Calibration';
            app.RunTxCalibrationButton.FontSize = 30;
            app.RunTxCalibrationButton.Position = [260 484 267 43];

            % Create AnalogRxFilterTuningButton
            app.AnalogRxFilterTuningButton = uibutton(app.RFCalibrationTab, 'state');
            app.AnalogRxFilterTuningButton.ValueChangedFcn = createCallbackFcn(app, @AnalogRxFilterTuningButtonValueChanged, true);
            app.AnalogRxFilterTuningButton.Text = 'Analog Rx Filter Tuning';
            app.AnalogRxFilterTuningButton.FontSize = 30;
            app.AnalogRxFilterTuningButton.Position = [226 305 333 43];

            % Create RunRxCalibrationButton
            app.RunRxCalibrationButton = uibutton(app.RFCalibrationTab, 'state');
            app.RunRxCalibrationButton.ValueChangedFcn = createCallbackFcn(app, @RunRxCalibrationButtonValueChanged, true);
            app.RunRxCalibrationButton.Text = 'Run Rx Calibration';
            app.RunRxCalibrationButton.FontSize = 30;
            app.RunRxCalibrationButton.Position = [257 133 270 43];

            % Create DeviceSettingsTab
            app.DeviceSettingsTab = uitab(app.TabGroup);
            app.DeviceSettingsTab.Title = 'Device Settings';

            % Create ScopeDropDownLabel
            app.ScopeDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.ScopeDropDownLabel.FontSize = 30;
            app.ScopeDropDownLabel.Position = [34 467 99 36];
            app.ScopeDropDownLabel.Text = 'Scope:';

            % Create ScopeDropDown
            app.ScopeDropDown = uidropdown(app.DeviceSettingsTab);
            app.ScopeDropDown.Items = {};
            app.ScopeDropDown.FontSize = 30;
            app.ScopeDropDown.Position = [132 467 615 36];
            app.ScopeDropDown.Value = {};

            % Create AWGDropDownLabel
            app.AWGDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.AWGDropDownLabel.FontSize = 30;
            app.AWGDropDownLabel.Position = [34 352 84 36];
            app.AWGDropDownLabel.Text = 'AWG:';

            % Create AWGDropDown
            app.AWGDropDown = uidropdown(app.DeviceSettingsTab);
            app.AWGDropDown.Items = {};
            app.AWGDropDown.FontSize = 30;
            app.AWGDropDown.Position = [132 352 615 36];
            app.AWGDropDown.Value = {};

            % Create RefreshDeviceListButton
            app.RefreshDeviceListButton = uibutton(app.DeviceSettingsTab, 'push');
            app.RefreshDeviceListButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshDeviceListButtonPushed, true);
            app.RefreshDeviceListButton.FontSize = 30;
            app.RefreshDeviceListButton.Position = [253 111 279 43];
            app.RefreshDeviceListButton.Text = 'Refresh Device List';

            % Create RefreshLamp
            app.RefreshLamp = uilamp(app.DeviceSettingsTab);
            app.RefreshLamp.Position = [725 29 34 34];

            % Create EnableSimulatorModeCheckBox
            app.EnableSimulatorModeCheckBox = uicheckbox(app.DeviceSettingsTab);
            app.EnableSimulatorModeCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableSimulatorModeCheckBoxValueChanged, true);
            app.EnableSimulatorModeCheckBox.Text = 'Enable Simulator Mode';
            app.EnableSimulatorModeCheckBox.FontSize = 30;
            app.EnableSimulatorModeCheckBox.Position = [223 38 339 34];

            % Create SimulatedAWGNSNREditFieldLabel
            app.SimulatedAWGNSNREditFieldLabel = uilabel(app.MQAMSystemv075UIFigure);
            app.SimulatedAWGNSNREditFieldLabel.FontSize = 30;
            app.SimulatedAWGNSNREditFieldLabel.Position = [81 -320 315 36];
            app.SimulatedAWGNSNREditFieldLabel.Text = 'Simulated AWGN SNR';

            % Create SimulatedAWGNSNREditField
            app.SimulatedAWGNSNREditField = uieditfield(app.MQAMSystemv075UIFigure, 'numeric');
            app.SimulatedAWGNSNREditField.FontSize = 30;
            app.SimulatedAWGNSNREditField.Position = [444 -324 100 36];
            app.SimulatedAWGNSNREditField.Value = 100;

            % Show the figure after all components are created
            app.MQAMSystemv075UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = mqamApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.MQAMSystemv075UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.MQAMSystemv075UIFigure)
        end
    end
end