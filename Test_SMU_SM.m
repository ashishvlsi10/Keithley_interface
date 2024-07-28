function runSlotMeasurement()
    % Clear existing instruments and workspace
    instruments = instrfind;
    for i = 1:numel(instruments)
        fclose(instruments(i));
        delete(instruments(i));
    end
    delete(instruments);
    clear;
    clc;

    % Prompt user for starting voltage, ending voltage, and number of steps
    SV = input('Enter the starting voltage: ');
    EV = input('Enter the ending voltage: ');
    numSteps = input('Enter the total number of steps: ');

    % Ask if user wants to use dual mode scanning
    dualMode = input('Use dual mode scanning? (1 for yes, 0 for no): ');

    if dualMode
        numTimes = input('Enter the number of times to repeat the scan: ');
        voltages = [linspace(SV, EV, numSteps), linspace(EV, SV, numSteps)];
        numSteps = numSteps * 2;
        voltages = repmat(voltages, 1, numTimes);
    else
        voltages = linspace(SV, EV, numSteps);
    end

    % Define slot-specific settings
    slots = [1, 2];
    devices_slot1 = 1:6;
    devices_slot2 = 7:12;
    channelToClose_slots = [1, 7];

    % Loop over each slot
    for slot = slots
        % Connect to the Keithley SourceMeter and switch matrix for the current slot
        smu = visa('ni', 'USB0::0x05E6::0x2604::4444456::INSTR');
        fopen(smu);
        matrix = visa('ni', 'USB0::0x05E6::0x707B::04016714::INSTR');
        fopen(matrix);

        % Define row and column addresses based on the slot number
        if slot == 1
            fprintf(matrix, ['channel.setlabelrow("1A01", "SM1S") channel.setlabelrow("1B01", "SM1D") ' ...
                'channel.setlabelrow("1C01", "None") ' ...
                'channel.setlabelrow("1G01", "CVUH") channel.setlabelrow("1H01", "CVUL")']);
            fprintf(matrix, ['channel.setlabelcolumn("1A01", "D1S")' ...
                'channel.setlabelcolumn("1B02", "D1D")' ...
                'channel.setlabelcolumn("1C03", "D2S")' ...
                'channel.setlabelcolumn("1D04", "D2D")' ...
                'channel.setlabelcolumn("1E05", "D3S")' ...
                'channel.setlabelcolumn("1F06", "D3D")' ...
                'channel.setlabelcolumn("1G07", "D4S")' ...
                'channel.setlabelcolumn("1H08", "D4D")' ...
                'channel.setlabelcolumn("1A09", "D5S")' ...
                'channel.setlabelcolumn("1A10", "D5D")' ...
                'channel.setlabelcolumn("1A11", "D6S")' ...
                'channel.setlabelcolumn("1A12", "D6D")']);
            devices = devices_slot1;
        else
            fprintf(matrix, ['channel.setlabelrow("2A01", "SM2S") channel.setlabelrow("2B01", "SM2D") ' ...
                'channel.setlabelrow("2C01", "None") ' ...
                'channel.setlabelrow("2G01", "CVUH") channel.setlabelrow("2H01", "CVUL")']);
            fprintf(matrix, ['channel.setlabelcolumn("2A01", "D7S")' ...
                'channel.setlabelcolumn("2B02", "D7D")' ...
                'channel.setlabelcolumn("2C03", "D8S")' ...
                'channel.setlabelcolumn("2D04", "D8D")' ...
                'channel.setlabelcolumn("2E05", "D9S")' ...
                'channel.setlabelcolumn("2F06", "D9D")' ...
                'channel.setlabelcolumn("2G07", "D10S")' ...
                'channel.setlabelcolumn("2H08", "D10D")' ...
                'channel.setlabelcolumn("2A09", "D11S")' ...
                'channel.setlabelcolumn("2A10", "D11D")' ...
                'channel.setlabelcolumn("2A11", "D12S")' ...
                'channel.setlabelcolumn("2A12", "D12D")']);
            devices = devices_slot2;
        end

        % Define function to close channels based on device number
        closeChannels = @(device) fprintf(matrix, ['channel.close("SM' num2str(slot) 'S+D' num2str(device) 'S")' ...
            'channel.close("SM' num2str(slot) 'D+D' num2str(device) 'D")']);

        % Define function to open channels based on device number
        openChannels = @(device) fprintf(matrix, ['channel.open("SM' num2str(slot) 'S+D' num2str(device) 'S")' ...
            'channel.open("SM' num2str(slot) 'D+D' num2str(device) 'D")']);

        % Set initial channel to close
        channelToClose = channelToClose_slots(slot);

        % Loop over each device in the current slot
        for device = devices
            % Close channel for the selected device
            closeChannels(channelToClose);

            % Open channels for all other devices
            for otherDevice = devices
                if otherDevice ~= channelToClose
                    openChannels(otherDevice);
                end
            end

            % Reset the SourceMeter
            fprintf(smu, '*RST');
            fprintf(smu, '*CLS');

            % Clear SMU error queue
            fprintf(smu, 'errorqueue.clear()');

            % Open a file to append data
            dataFile = fopen(['m' num2str(slot) '_data_Device' num2str(device) '.xls'], 'a');
            % Write column headers to the file
            fprintf(dataFile, 'Voltage (V)\tCurrent (A)\n');

            % Set channel A for constant bias voltage
            fprintf(smu, 'smua.source.func = smua.OUTPUT_DCVOLTS');
            fprintf(smu, 'smua.source.autorangev = smua.AUTORANGE_ON');
            fprintf(smu, 'smua.measure.nplc = 1'); % set nplc 1
            fprintf(smu, 'smua.source.levelv = 0.1'); % Set the bias voltage to 0.1V

            % Set channel B for voltage sweep
            fprintf(smu, 'smub.source.func = smub.OUTPUT_DCVOLTS');
            fprintf(smu, 'smub.source.rangev = %f', max(abs(SV), abs(EV)));
            fprintf(smu, 'smub.sense = smub.SENSE_LOCAL');
            fprintf(smu, 'smub.measure.nplc = 1');
            fprintf(smu, 'smub.measure.rangev = smub.source.rangev');
            fprintf(smu, 'smub.measure.autozero = smub.AUTOZERO_ONCE');
            fprintf(smu, 'smub.measure.rangei = smub.AUTORANGE_ON');
            fprintf(smu, 'smub.nvbuffer1.clear()');

            % Enable output
            fprintf(smu, 'smua.source.output = smua.OUTPUT_ON');
            fprintf(smu, 'smub.source.output = smub.OUTPUT_ON');

            current = zeros(1, numel(voltages));

            for i = 1:numel(voltages)
                % Set the voltage level for Channel A
                fprintf(smu, sprintf('smub.source.levelv = %f', voltages(i)));

                % Measure the current on Channel A
                fprintf(smu, 'smua.measure.i(smua.nvbuffer1)');
                % Read the measured current
                current_str = query(smu, 'printbuffer(1, smua.nvbuffer1.n, smua.nvbuffer1.readings)');
                current(i) = str2double(current_str);

                % Append the voltage and current to the file
                fprintf(dataFile, '%.3f\t%.10f\n', voltages(i), current(i));
            end

            % Close the file
            fclose(dataFile);

            % Plot and save the voltage-current data
            fig = figure;
            plot(voltages, current);
            xlabel('Voltage (V)');
            ylabel('Current (A)');
            title(['Device ' num2str(device) ' - Slot ' num2str(slot)]);
            saveas(fig, ['Device_' num2str(device) '_Plot_Slot' num2str(slot) '.png']);

            % Update channel to close for the next iteration
            channelToClose = mod(channelToClose, numel(devices)) + devices(1);

            % Open channels for all devices after measuring all devices
            if device == devices(end)
                for device = devices
                    openChannels(device);
                end
            end
        end

        % Close and delete SMU and matrix connections
        fprintf(smu, '*RST');
        fprintf(smu, '*CLS');
        fclose(smu);
        delete(smu);
        fclose(matrix);
        delete(matrix);
    end
end
