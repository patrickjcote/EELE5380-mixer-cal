classdef mqamApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        MQAMSystemUIFigure             matlab.ui.Figure
        MQAMDropDownLabel              matlab.ui.control.Label
        MQAMDropDown                   matlab.ui.control.DropDown
        FrameLengthsymbolsEditFieldLabel  matlab.ui.control.Label
        FrameLengthsymbolsEditField    matlab.ui.control.NumericEditField
        RandomSeedEditFieldLabel       matlab.ui.control.Label
        RandomSeedEditField            matlab.ui.control.NumericEditField
        SymbolRatesymssecEditFieldLabel  matlab.ui.control.Label
        SymbolRatesymssecEditField     matlab.ui.control.NumericEditField
        TotalFrameLengthLabel          matlab.ui.control.Label
        secondsLabel                   matlab.ui.control.Label
        SendButton                     matlab.ui.control.StateButton
        ReadButton                     matlab.ui.control.StateButton
        ApplyTxCalibrationSwitchLabel  matlab.ui.control.Label
        ApplyTxCalibrationSwitch       matlab.ui.control.ToggleSwitch
        ApplyRxCalibrationSwitchLabel  matlab.ui.control.Label
        ApplyRxCalibrationSwitch       matlab.ui.control.ToggleSwitch
    end

    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            addpath('functions\');
        end

        % Value changed function: SendButton
        function SendButtonValueChanged(app, event)
            
            M = str2num(app.MQAMDropDown.Value);
            Fsym = app.SymbolRatesymssecEditField.Value;
            N_syms = app.FrameLengthsymbolsEditField.Value;
            rng_seed = app.RandomSeedEditField.Value;
            switch app.ApplyTxCalibrationSwitch.Value
                case 'Off'
                    TX_CAL = 0;
                otherwise
                    TX_CAL = 1;
            end
            
            buildMQAM(M,Fsym,N_syms,rng_seed,TX_CAL);
            
            app.SendButton.Value = 0;
            
        end

        % Value changed function: ReadButton
        function ReadButtonValueChanged(app, event)
            M = str2num(app.MQAMDropDown.Value);
            Fsym = app.SymbolRatesymssecEditField.Value;
            N_syms = app.FrameLengthsymbolsEditField.Value;
            rng_seed = app.RandomSeedEditField.Value;
            
            switch app.ApplyRxCalibrationSwitch.Value
                case 'Off'
                    RX_CAL = 0;
                otherwise
                    RX_CAL = 1;
            end
            
            readMQAM(M,Fsym,N_syms,rng_seed,RX_CAL);
            
            app.ReadButton.Value = 0;
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create MQAMSystemUIFigure
            app.MQAMSystemUIFigure = uifigure;
            app.MQAMSystemUIFigure.Position = [100 100 338 375];
            app.MQAMSystemUIFigure.Name = 'M-QAM System';

            % Create MQAMDropDownLabel
            app.MQAMDropDownLabel = uilabel(app.MQAMSystemUIFigure);
            app.MQAMDropDownLabel.Position = [21 325 47 22];
            app.MQAMDropDownLabel.Text = 'M-QAM';

            % Create MQAMDropDown
            app.MQAMDropDown = uidropdown(app.MQAMSystemUIFigure);
            app.MQAMDropDown.Items = {'4', '16', '32', '64', '128', '256', '512', '1024'};
            app.MQAMDropDown.Editable = 'on';
            app.MQAMDropDown.BackgroundColor = [1 1 1];
            app.MQAMDropDown.Position = [155 325 144 22];
            app.MQAMDropDown.Value = '4';

            % Create FrameLengthsymbolsEditFieldLabel
            app.FrameLengthsymbolsEditFieldLabel = uilabel(app.MQAMSystemUIFigure);
            app.FrameLengthsymbolsEditFieldLabel.Position = [21 256 136 22];
            app.FrameLengthsymbolsEditFieldLabel.Text = 'Frame Length (symbols)';

            % Create FrameLengthsymbolsEditField
            app.FrameLengthsymbolsEditField = uieditfield(app.MQAMSystemUIFigure, 'numeric');
            app.FrameLengthsymbolsEditField.Position = [199 256 100 22];
            app.FrameLengthsymbolsEditField.Value = 2000;

            % Create RandomSeedEditFieldLabel
            app.RandomSeedEditFieldLabel = uilabel(app.MQAMSystemUIFigure);
            app.RandomSeedEditFieldLabel.Position = [19 191 82 22];
            app.RandomSeedEditFieldLabel.Text = 'Random Seed';

            % Create RandomSeedEditField
            app.RandomSeedEditField = uieditfield(app.MQAMSystemUIFigure, 'numeric');
            app.RandomSeedEditField.Position = [199 191 100 22];
            app.RandomSeedEditField.Value = 2369;

            % Create SymbolRatesymssecEditFieldLabel
            app.SymbolRatesymssecEditFieldLabel = uilabel(app.MQAMSystemUIFigure);
            app.SymbolRatesymssecEditFieldLabel.Position = [21 289 136 22];
            app.SymbolRatesymssecEditFieldLabel.Text = 'Symbol Rate (syms/sec)';

            % Create SymbolRatesymssecEditField
            app.SymbolRatesymssecEditField = uieditfield(app.MQAMSystemUIFigure, 'numeric');
            app.SymbolRatesymssecEditField.Position = [199 289 100 22];
            app.SymbolRatesymssecEditField.Value = 1000;

            % Create TotalFrameLengthLabel
            app.TotalFrameLengthLabel = uilabel(app.MQAMSystemUIFigure);
            app.TotalFrameLengthLabel.Position = [21 225 112 22];
            app.TotalFrameLengthLabel.Text = 'Total Frame Length:';

            % Create secondsLabel
            app.secondsLabel = uilabel(app.MQAMSystemUIFigure);
            app.secondsLabel.HorizontalAlignment = 'right';
            app.secondsLabel.Position = [199 225 100 22];
            app.secondsLabel.Text = '2 seconds';

            % Create SendButton
            app.SendButton = uibutton(app.MQAMSystemUIFigure, 'state');
            app.SendButton.ValueChangedFcn = createCallbackFcn(app, @SendButtonValueChanged, true);
            app.SendButton.Text = 'Send';
            app.SendButton.Position = [27 39 100 22];

            % Create ReadButton
            app.ReadButton = uibutton(app.MQAMSystemUIFigure, 'state');
            app.ReadButton.ValueChangedFcn = createCallbackFcn(app, @ReadButtonValueChanged, true);
            app.ReadButton.Text = 'Read';
            app.ReadButton.Position = [199 39 100 22];

            % Create ApplyTxCalibrationSwitchLabel
            app.ApplyTxCalibrationSwitchLabel = uilabel(app.MQAMSystemUIFigure);
            app.ApplyTxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyTxCalibrationSwitchLabel.Position = [21 123 113 22];
            app.ApplyTxCalibrationSwitchLabel.Text = 'Apply Tx Calibration';

            % Create ApplyTxCalibrationSwitch
            app.ApplyTxCalibrationSwitch = uiswitch(app.MQAMSystemUIFigure, 'toggle');
            app.ApplyTxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyTxCalibrationSwitch.Position = [60 99 38 16];
            app.ApplyTxCalibrationSwitch.Value = 'On';

            % Create ApplyRxCalibrationSwitchLabel
            app.ApplyRxCalibrationSwitchLabel = uilabel(app.MQAMSystemUIFigure);
            app.ApplyRxCalibrationSwitchLabel.HorizontalAlignment = 'center';
            app.ApplyRxCalibrationSwitchLabel.Position = [189 123 118 22];
            app.ApplyRxCalibrationSwitchLabel.Text = ' Apply Rx Calibration';

            % Create ApplyRxCalibrationSwitch
            app.ApplyRxCalibrationSwitch = uiswitch(app.MQAMSystemUIFigure, 'toggle');
            app.ApplyRxCalibrationSwitch.Orientation = 'horizontal';
            app.ApplyRxCalibrationSwitch.Position = [229 100 38 16];
            app.ApplyRxCalibrationSwitch.Value = 'On';
        end
    end

    methods (Access = public)

        % Construct app
        function app = mqamApp

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.MQAMSystemUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.MQAMSystemUIFigure)
        end
    end
end