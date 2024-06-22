function runSlotMeasurement()

    %%% Program for slot 1

    % Find all instrument objects
    instruments = instrfind;

    % Close and delete each instrument object
    for i = 1:numel(instruments)
        fclose(instruments(i));
        delete(instruments(i));
    end

    % Clear the instrument objects
    delete(instruments);
    clear instruments;

    clear; % clear workspace 
    clc; % clear command window 

    % Connect to the Keithley SourceMeter and switch matrix for slot 1
    smu_slot1 = visa('ni', 'USB0::0x05E6::0x2604::4444456::INSTR');
    fopen(smu_slot1);
    matrix_slot1 = visa('ni', 'USB0::0x05E6::0x707B::04016714::INSTR');
    fopen(matrix_slot1);

    %%% Define row address in slot 1

    fprintf(matrix_slot1, ['channel.setlabelrow("1A01", "SM1S") channel.setlabelrow("1B01", "SM1D") ' ...
        'channel.setlabelrow("1C01", "None") ' ...
        'channel.setlabelrow("1G01", "CVUH") channel.setlabelrow("1H01", "CVUL")']);

    fprintf(matrix_slot1,['channel.setlabelcolumn("1A01", "D1S")' ...
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

    % Define function to close channels based on device number for slot 1
    closeChannels_slot1 = @(device) fprintf(matrix_slot1, ['channel.close("SM1S+D' num2str(device) 'S")' ...
        'channel.close("SM1D+D' num2str(device) 'D")']);

    % Define function to open channels based on device number for slot 1
    openChannels_slot1 = @(device) fprintf(matrix_slot1, ['channel.open("SM1S+D' num2str(device) 'S")' ...
        'channel.open("SM1D+D' num2str(device) 'D")']);

    % Prompt user for starting voltage, ending voltage, and number of steps for slot 1
    SV_slot1 = input('Enter the starting voltage for slot 1: ');
    EV_slot1 = input('Enter the ending voltage for slot 1: ');
    numSteps_slot1 = input('Enter the total number of steps for slot 1: ');

    % Set initial channel to close for slot 1
    channelToClose_slot1 = 1;

    % Loop over each device in slot 1
    for device = 1:6
        % Close channel for the selected device for slot 1
        closeChannels_slot1(channelToClose_slot1);

        % Open channels for all other devices for slot 1
        for otherDevice = 1:6
            if otherDevice ~= channelToClose_slot1
                openChannels_slot1(otherDevice);
            end
        end

        % Reset the SourceMeter for slot 1
        fprintf(smu_slot1, '*RST');
        fprintf(smu_slot1, '*CLS');

        % Clear SMU error queue for slot 1
        fprintf(smu_slot1, 'errorqueue.clear()');

        % Open a file to append data for slot 1
        dataFile_slot1 = fopen(['m1_data_Device' num2str(device) '.xls'], 'a');
        % Write column headers to the file for slot 1
        fprintf(dataFile_slot1, 'Voltage (V)\tCurrent (A)\n');

        % Sweep voltage from starting to ending voltage for slot 1
        voltages_slot1 = linspace(SV_slot1, EV_slot1, numSteps_slot1);

        % Set channel A for voltage sweep for slot 1
        fprintf(smu_slot1, 'smua.source.func = smua.OUTPUT_DCVOLTS');
        fprintf(smu_slot1, 'smua.source.rangev = math.max(math.abs(SV_slot1), math.abs(EV_slot1))');
        fprintf(smu_slot1, 'smua.sense = smua.SENSE_LOCAL');
        fprintf(smu_slot1, 'smua.measure.nplc = 1');
        fprintf(smu_slot1, 'smua.measure.rangev = smub.source.rangev');
        fprintf(smu_slot1, 'smua.measure.autozero = smub.AUTOZERO_ONCE');
        fprintf(smu_slot1, 'smua.measure.rangei = pulseLimit');
        fprintf(smu_slot1, 'smua.nvbuffer1.clear()');

        % Enable output for slot 1
        fprintf(smu_slot1, 'smua.source.output = smua.OUTPUT_ON');

        current_slot1 = zeros(1, numel(voltages_slot1));

        for i = 1:numel(voltages_slot1)
            % Set the voltage level for Channel B for slot 1
            fprintf(smu_slot1, sprintf('smua.source.levelv = %f', voltages_slot1(i)));

            % Measure the current on Channel A for slot 1
            fprintf(smu_slot1, 'smua.measure.i(smua.nvbuffer1)');
            % Read the measured current for slot 1
            current_str_slot1 = query(smu_slot1, 'printbuffer(1, smua.nvbuffer1.n, smua.nvbuffer1.readings)');
            current_slot1(i) = str2double(current_str_slot1);

            % Append the voltage and current to the file for slot 1
            fprintf(dataFile_slot1, '%.3f\t%.10f\n', voltages_slot1(i), current_slot1(i));
        end

        % Close the file for slot 1
        fclose(dataFile_slot1);

        % Plot and save the voltage-current data for slot 1
        fig_slot1 = figure;
        plot(voltages_slot1, current_slot1);
        xlabel('Voltage (V)');
        ylabel('Current (A)');
        title(['Device ' num2str(device) ' - Slot 1']);
        saveas(fig_slot1, ['Device_' num2str(device) '_Plot_Slot1.png']);

        % Update channel to close for the next iteration for slot 1
        channelToClose_slot1 = mod(channelToClose_slot1, 6) + 1;

        % Open channels for all devices in slot 1 after measuring all devices
        if device == 6
            for device_slot1 = 1:6
                openChannels_slot1(device_slot1);
            end
        end
    end

    %%% Program for slot 2

    % Connect to the Keithley SourceMeter and switch matrix for slot 2
    % Close and delete instruments for slot 1
    fclose(smu_slot1);
    fclose(matrix_slot1);
    delete(smu_slot1);
    delete(matrix_slot1);
    clear smu_slot1 matrix_slot1;

    smu_slot2 = visa('ni', 'USB0::0x05E6::0x2604::4444456::INSTR');
    fopen(smu_slot2);
    matrix_slot2 = visa('ni', 'USB0::0x05E6::0x707B::04016714::INSTR');
    fopen(matrix_slot2);



    % Define row address in slot 2
    fprintf(matrix_slot2, ['channel.setlabelrow("2A01", "SM2S") channel.setlabelrow("2B01", "SM2D") ' ...
        'channel.setlabelrow("2C01", "None") ' ...
        'channel.setlabelrow("2G01", "CVUH") channel.setlabelrow("2H01", "CVUL")']);

    % Define column address for slot 2
    fprintf(matrix_slot2,['channel.setlabelcolumn("2A01", "D7S")' ...
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

    % Define function to close channels based on device number for slot 2
    closeChannels_slot2 = @(device) fprintf(matrix_slot2, ['channel.close("SM2S+D' num2str(device) 'S")' ...
        'channel.close("SM2D+D' num2str(device) 'D")']);

    % Define function to open channels based on device number for slot 2
    openChannels_slot2 = @(device) fprintf(matrix_slot2, ['channel.open("SM2S+D' num2str(device) 'S")' ...
        'channel.open("SM2D+D' num2str(device) 'D")']);

    % Prompt user for starting voltage, ending voltage, and number of steps for slot 2
    SV_slot2 = SV_slot1; % Use the same values as for slot 1
    EV_slot2 = EV_slot1; % Use the same values as for slot 1
    numSteps_slot2 = numSteps_slot1; % Use the same values as for slot 1

    % Set initial channel to close for slot 2
    channelToClose_slot2 = 7;

    % Loop over each device in slot 2
    for device_slot2 = 7:12
        % Close channel for the selected device for slot 2
        closeChannels_slot2(channelToClose_slot2);

        % Open channels for all other devices for slot 2
        for otherDevice_slot2 = 7:12
            if otherDevice_slot2 ~= device_slot2
                openChannels_slot2(otherDevice_slot2);
            end
        end

        % Reset the SourceMeter for slot 2
        fprintf(smu_slot2, '*RST');
        fprintf(smu_slot2, '*CLS');

        % Clear SMU error queue for slot 2
        fprintf(smu_slot2, 'errorqueue.clear()');

        % Open a file to append data for slot 2
        dataFile_slot2 = fopen(['m2_data_Device' num2str(device_slot2) '.xls'], 'a');
        % Write column headers to the file for slot 2
        fprintf(dataFile_slot2, 'Voltage (V)\tCurrent (A)\n');

        % Sweep voltage from starting to ending voltage for slot 2
        voltages_slot2 = linspace(SV_slot2, EV_slot2, numSteps_slot2);

        % Set channel A for voltage sweep for slot 2
        fprintf(smu_slot2, 'smua.source.func = smua.OUTPUT_DCVOLTS');
        fprintf(smu_slot2, 'smua.source.rangev = math.max(math.abs(SV_slot2), math.abs(EV_slot2))');
        fprintf(smu_slot2, 'smua.sense = smua.SENSE_LOCAL');
        fprintf(smu_slot2, 'smua.measure.nplc = 1');
        fprintf(smu_slot2, 'smua.measure.rangev = smua.source.rangev');
        fprintf(smu_slot2, 'smua.measure.autozero = smua.AUTOZERO_ONCE');
        fprintf(smu_slot2, 'smua.measure.rangei = smua.AUTO_RANGE_ON');
        fprintf(smu_slot2, 'smua.nvbuffer1.clear()');

        % Enable output for slot 2
        fprintf(smu_slot2, 'smua.source.output = smua.OUTPUT_ON');

        current_slot2 = zeros(1, numel(voltages_slot2));

        for i = 1:numel(voltages_slot2)
            % Set the voltage level for Channel A for slot 2
            fprintf(smu_slot2, sprintf('smua.source.levelv = %f', voltages_slot2(i)));

            % Measure the current on Channel A for slot 2
            fprintf(smu_slot2, 'smua.measure.i(smua.nvbuffer1)');
            % Read the measured current for slot 2
            current_str_slot2 = query(smu_slot2, 'printbuffer(1, smua.nvbuffer1.n, smua.nvbuffer1.readings)');
            current_slot2(i) = str2double(current_str_slot2);

            % Append the voltage and current to the file for slot 2
            fprintf(dataFile_slot2, '%.3f\t%.10f\n', voltages_slot2(i), current_slot2(i));
        end

        % Close the file for slot 2
        fclose(dataFile_slot2);

        % Plot and save the voltage-current data for slot 2
        fig_slot2 = figure;
        plot(voltages_slot2, current_slot2);
        xlabel('Voltage (V)');
        ylabel('Current (A)');
        title(['Device ' num2str(device_slot2) ' - Slot 2']);
        saveas(fig_slot2, ['Device_' num2str(device_slot2) '_Plot_Slot2.png']);

        % Update channel to close for the next iteration for slot 2
        channelToClose_slot2 = mod(channelToClose_slot2, 12) + 1;



    end


    % Open all closed channels for slot 2  

    for device_slot2 = 7:12
        openChannels_slot2(device_slot2);
    end

    % Routine for closing switch matrix for slot 2
    fclose(smu_slot2);
    fclose(matrix_slot2);
    delete(smu_slot2);
    delete(matrix_slot2);
    clear smu_slot2 matrix_slot2;

end
