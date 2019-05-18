classdef mixerCalibration < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        EMONATIMSMixerCalibrationv05UIFigure  matlab.ui.Figure
        TabGroup                      matlab.ui.container.TabGroup
        MixerCalibrationTab           matlab.ui.container.Tab
        RunTxCalibrationButton        matlab.ui.control.StateButton
        AnalogRxFilterTuningButton    matlab.ui.control.StateButton
        RunRxCalibrationButton        matlab.ui.control.StateButton
        Status                        matlab.ui.control.Label
        DeviceSettingsTab             matlab.ui.container.Tab
        ScopeDropDownLabel            matlab.ui.control.Label
        ScopeDropDown                 matlab.ui.control.DropDown
        AWGLabel                      matlab.ui.control.Label
        AWGDropDown                   matlab.ui.control.DropDown
        RefreshDeviceListButton       matlab.ui.control.Button
        RefreshLamp                   matlab.ui.control.Lamp
        ReadSingleSidebandButton      matlab.ui.control.StateButton
        VISADeviceAddressEditFieldLabel  matlab.ui.control.Label
        VISADeviceAddressEditField    matlab.ui.control.EditField
        VISADriverTypeEditFieldLabel  matlab.ui.control.Label
        VISADriverTypeEditField       matlab.ui.control.EditField
        EnableSimulatorModeCheckBox   matlab.ui.control.CheckBox
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
%             devices = scanVISA();
                            load('scanVisaOutput3.mat','devices');
            
            if ~iscell(devices)
                % Devices structure is empty, load Items
                app.ScopeDropDown.Items{1} = 'No Devices Found.';
                app.AWGDropDown.Items{1} = 'No Devices Found.';
                % Force App to select Device Setting Tab
                app.TabGroup.SelectedTab = app.DeviceSettingsTab;
                % Set status lamp color
                app.RefreshLamp.Color = 'Red';
                % Disable Calibration Function Buttons
                app.RunRxCalibrationButton.Enable = 0;
                app.RunTxCalibrationButton.Enable = 0;
                app.AnalogRxFilterTuningButton.Enable = 0;
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
                
                % Enable Calibration Function Buttons
                app.RunRxCalibrationButton.Enable = 1;
                app.RunTxCalibrationButton.Enable = 1;
                app.AnalogRxFilterTuningButton.Enable = 1;
                app.Status.Text = '';
                
                % Device refresh successful, set lamp to green
                app.RefreshLamp.Color = 'Green';
            end
            
        end
    end
    

    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            addpath('functions\');
            
            % Set Lamp
            app.RefreshLamp.Color = 'Yellow';
            refreshDevices(app);
            
        end

        % Callback function
        function AmpSliderValueChanged(app, event)
            
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
            app.EMONATIMSMixerCalibrationv05UIFigure.Visible = 0;
            app.EMONATIMSMixerCalibrationv05UIFigure.Visible = 1;
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
            app.EMONATIMSMixerCalibrationv05UIFigure.Visible = 0;
            app.EMONATIMSMixerCalibrationv05UIFigure.Visible = 1;
        end

        % Callback function
        function BuildRxCalFilesButtonValueChanged(app, event)

            
        end

        % Value changed function: AnalogRxFilterTuningButton
        function AnalogRxFilterTuningButtonValueChanged(app, event)
            
            
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
            if ~SIM_MODE
                
                DSOVisa = app.ScopeDropDown.Value;
                DSOVisaType = DSOVisa.type;
                DSOVisaAddr = DSOVisa.addr;
            
    
            
                
                app.Status.Text = 'Setting Up Filter Calibration';
                app.Status.FontColor = 'Black';
                try
                    
                    % Send Pulse to AWG
                    buildFiltCal();
                    % Set Rigol to Filter Viewing mode
                    setRigol(4,[],[],DSOVisaType,DSOVisaAddr);
                    
                    app.Status.Text = 'DSO Set Successful';
                    app.Status.FontColor = [0.47 0.67 0.19];
                    
                    
                    % PLot Examples
                    if isfile('Data Files\filter_tuned.mat') && isfile('Data Files\filter_untuned.mat')

                        a = load('Data Files\filter_untuned.mat');
                        figure;
                        plot(a.tq,a.F1rx,a.tq,a.F2rx);
                        grid on; grid minor;
                        legend('Filter One','Filter Two');
                        title('Example of a Untuned Filter Response (Not Live Data)');
                        
                        a = load('Data Files\filter_tuned.mat');
                        figure
                        plot(a.tq,a.F1rx,a.tq,a.F2rx);
                        grid on; grid minor;
                        legend('Filter One','Filter Two (Not Live Data)');
                        title('Example of a Tuned Filter Response');
                        
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
                    title('Example Untuned Filter Response');
                    
                    a = load('Data Files\filter_tuned.mat');
                    figure
                    plot(a.tq,a.F1rx,a.tq,a.F2rx);
                    grid on; grid minor;
                    legend('Filter One','Filter Two');
                    title('Example Tuned Filter Response');
                    
                end
            end
            
            app.AnalogRxFilterTuningButton.Value = 0;
            % Disable/Enable visablity to bring app window back to the foreground
            app.EMONATIMSMixerCalibrationv05UIFigure.Visible = 0;
            app.EMONATIMSMixerCalibrationv05UIFigure.Visible = 1;
            
        end

        % Value changed function: ReadSingleSidebandButton
        function ReadSingleSidebandButtonValueChanged(app, event)
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
            readRx_sb_calcd
            app.ReadSingleSidebandButton.Value = 0;
            
        end

        % Value changed function: EnableSimulatorModeCheckBox
        function EnableSimulatorModeCheckBoxValueChanged(app, event)
            global SIM_MODE
            SIM_MODE = app.EnableSimulatorModeCheckBox.Value;
        end

        % Button pushed function: RefreshDeviceListButton
        function RefreshDeviceListButtonPushed(app, event)
            refreshDevices(app);
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create EMONATIMSMixerCalibrationv05UIFigure
            app.EMONATIMSMixerCalibrationv05UIFigure = uifigure;
            app.EMONATIMSMixerCalibrationv05UIFigure.Position = [100 100 397 291];
            app.EMONATIMSMixerCalibrationv05UIFigure.Name = 'EMONA TIMS Mixer Calibration v0.5';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.EMONATIMSMixerCalibrationv05UIFigure);
            app.TabGroup.Position = [1 1 397 291];

            % Create MixerCalibrationTab
            app.MixerCalibrationTab = uitab(app.TabGroup);
            app.MixerCalibrationTab.Title = 'Mixer Calibration';

            % Create RunTxCalibrationButton
            app.RunTxCalibrationButton = uibutton(app.MixerCalibrationTab, 'state');
            app.RunTxCalibrationButton.ValueChangedFcn = createCallbackFcn(app, @RunTxCalibrationButtonValueChanged, true);
            app.RunTxCalibrationButton.Text = 'Run Tx Calibration';
            app.RunTxCalibrationButton.Position = [142 188 115 22];

            % Create AnalogRxFilterTuningButton
            app.AnalogRxFilterTuningButton = uibutton(app.MixerCalibrationTab, 'state');
            app.AnalogRxFilterTuningButton.ValueChangedFcn = createCallbackFcn(app, @AnalogRxFilterTuningButtonValueChanged, true);
            app.AnalogRxFilterTuningButton.Text = 'Analog Rx Filter Tuning';
            app.AnalogRxFilterTuningButton.Position = [129 122 140 22];

            % Create RunRxCalibrationButton
            app.RunRxCalibrationButton = uibutton(app.MixerCalibrationTab, 'state');
            app.RunRxCalibrationButton.ValueChangedFcn = createCallbackFcn(app, @RunRxCalibrationButtonValueChanged, true);
            app.RunRxCalibrationButton.Text = 'Run Rx Calibration';
            app.RunRxCalibrationButton.Position = [141 64 116 22];

            % Create Status
            app.Status = uilabel(app.MixerCalibrationTab);
            app.Status.HorizontalAlignment = 'center';
            app.Status.Position = [48 12 302 22];
            app.Status.Text = '';

            % Create DeviceSettingsTab
            app.DeviceSettingsTab = uitab(app.TabGroup);
            app.DeviceSettingsTab.Title = 'Device Settings';

            % Create ScopeDropDownLabel
            app.ScopeDropDownLabel = uilabel(app.DeviceSettingsTab);
            app.ScopeDropDownLabel.Position = [19 188 43 22];
            app.ScopeDropDownLabel.Text = 'Scope:';

            % Create ScopeDropDown
            app.ScopeDropDown = uidropdown(app.DeviceSettingsTab);
            app.ScopeDropDown.Items = {};
            app.ScopeDropDown.Position = [77 188 304 22];
            app.ScopeDropDown.Value = {};

            % Create AWGLabel
            app.AWGLabel = uilabel(app.DeviceSettingsTab);
            app.AWGLabel.Position = [19 127 34 22];
            app.AWGLabel.Text = 'AWG:';

            % Create AWGDropDown
            app.AWGDropDown = uidropdown(app.DeviceSettingsTab);
            app.AWGDropDown.Items = {};
            app.AWGDropDown.Position = [77 127 304 22];
            app.AWGDropDown.Value = {};

            % Create RefreshDeviceListButton
            app.RefreshDeviceListButton = uibutton(app.DeviceSettingsTab, 'push');
            app.RefreshDeviceListButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshDeviceListButtonPushed, true);
            app.RefreshDeviceListButton.Position = [139 64 120 22];
            app.RefreshDeviceListButton.Text = 'Refresh Device List';

            % Create RefreshLamp
            app.RefreshLamp = uilamp(app.DeviceSettingsTab);
            app.RefreshLamp.Position = [361 22 20 20];

            % Create ReadSingleSidebandButton
            app.ReadSingleSidebandButton = uibutton(app.EMONATIMSMixerCalibrationv05UIFigure, 'state');
            app.ReadSingleSidebandButton.ValueChangedFcn = createCallbackFcn(app, @ReadSingleSidebandButtonValueChanged, true);
            app.ReadSingleSidebandButton.Enable = 'off';
            app.ReadSingleSidebandButton.Text = 'Read Single Sideband';
            app.ReadSingleSidebandButton.Position = [-253 -19 135 22];

            % Create VISADeviceAddressEditFieldLabel
            app.VISADeviceAddressEditFieldLabel = uilabel(app.EMONATIMSMixerCalibrationv05UIFigure);
            app.VISADeviceAddressEditFieldLabel.HorizontalAlignment = 'center';
            app.VISADeviceAddressEditFieldLabel.Position = [-245 116 120 22];
            app.VISADeviceAddressEditFieldLabel.Text = 'VISA Device Address';

            % Create VISADeviceAddressEditField
            app.VISADeviceAddressEditField = uieditfield(app.EMONATIMSMixerCalibrationv05UIFigure, 'text');
            app.VISADeviceAddressEditField.HorizontalAlignment = 'center';
            app.VISADeviceAddressEditField.FontSize = 11;
            app.VISADeviceAddressEditField.Position = [-321 95 278 22];
            app.VISADeviceAddressEditField.Value = 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR';

            % Create VISADriverTypeEditFieldLabel
            app.VISADriverTypeEditFieldLabel = uilabel(app.EMONATIMSMixerCalibrationv05UIFigure);
            app.VISADriverTypeEditFieldLabel.HorizontalAlignment = 'center';
            app.VISADriverTypeEditFieldLabel.Position = [-234 189 98 22];
            app.VISADriverTypeEditFieldLabel.Text = 'VISA Driver Type';

            % Create VISADriverTypeEditField
            app.VISADriverTypeEditField = uieditfield(app.EMONATIMSMixerCalibrationv05UIFigure, 'text');
            app.VISADriverTypeEditField.HorizontalAlignment = 'center';
            app.VISADriverTypeEditField.Position = [-259 168 147 22];
            app.VISADriverTypeEditField.Value = 'KEYSIGHT';

            % Create EnableSimulatorModeCheckBox
            app.EnableSimulatorModeCheckBox = uicheckbox(app.EMONATIMSMixerCalibrationv05UIFigure);
            app.EnableSimulatorModeCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableSimulatorModeCheckBoxValueChanged, true);
            app.EnableSimulatorModeCheckBox.Text = 'Enable Simulator Mode';
            app.EnableSimulatorModeCheckBox.Position = [-259 44 147 22];
        end
    end

    methods (Access = public)

        % Construct app
        function app = mixerCalibration

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.EMONATIMSMixerCalibrationv05UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.EMONATIMSMixerCalibrationv05UIFigure)
        end
    end
end