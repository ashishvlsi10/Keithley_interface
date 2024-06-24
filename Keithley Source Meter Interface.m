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

% Connect to the Keithley SourceMeter and switch matrix
smu = visa('ni', 'USB0::0x05E6::0x2604::4444456::INSTR');
fopen(smu);

id1 = query(smu, '*IDN?');
fprintf('Connected to %s\n', id1);

% Reset the SourceMeter
fprintf(smu, '*RST');
fprintf(smu, '*CLS');

% Clear SMU error queue
fprintf(smu, 'errorqueue.clear()');

% Prompt user to input the filename for the Excel file
filename = input('Enter the filename for the Excel file (without extension): ', 's');
excelFilename = strcat(filename, '.xlsx'); % Append .xlsx extension for Excel file
imageFilename = strcat(filename, '.png'); % Append .png extension for image file
headers = {'Voltage (V)', 'Current (A)'};

% Sweep voltage from -0.8 to 0.8 volts
SV = -0.8;
EV = 0.8;

numSteps = 401;
%numSteps = input('Enter the total number of steps: ');

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

% Set channel A for constant bias voltage
fprintf(smu, 'smua.source.func = smub.OUTPUT_DCVOLTS');
fprintf(smu, 'smua.source.autorangev = smub.AUTORANGE_ON');
fprintf(smu, 'smua.measure.nplc = 1'); % set nplc 1
fprintf(smu, 'smua.source.levelv = 0.1'); % Set the bias voltage to 0.1V

% Set channel B for voltage sweep
fprintf(smu, 'smub.source.func = smua.OUTPUT_DCVOLTS');
fprintf(smu, 'smub.source.rangev = %f', max(abs(SV), abs(EV)));
fprintf(smu, 'smub.sense = smua.SENSE_LOCAL');
fprintf(smu, 'smub.measure.nplc = 1');
fprintf(smu, 'smub.measure.rangev = smub.source.rangev');
fprintf(smu, 'smub.measure.autozero = smub.AUTOZERO_ONCE');
fprintf(smu, 'smub.measure.rangei = pulseLimit');
fprintf(smu, 'smub.nvbuffer1.clear()');

% Enable output
fprintf(smu, 'smua.source.output = smua.OUTPUT_ON');
fprintf(smu, 'smub.source.output = smub.OUTPUT_ON');

current = zeros(1, numel(voltages));

for i = 1:numel(voltages)
    % Set the voltage level for Channel B
    fprintf(smu, sprintf('smub.source.levelv = %f', voltages(i)));

    % Measure the current on Channel A
    fprintf(smu, 'smua.measure.i(smua.nvbuffer1)');
    % Read the measured current
    current_str = query(smu, 'printbuffer(1, smua.nvbuffer1.n, smua.nvbuffer1.readings)');
    current(i) = str2double(current_str);
    
    % Display the voltage and current
    fprintf('Voltage: %.3f V, Current: %.9f A\n', voltages(i), current(i));
end

% Save data to Excel
dataTable = table(voltages', current', 'VariableNames', headers);
writetable(dataTable, excelFilename);

% Routine for closing switch matrix
fprintf(smu, '*RST');
fprintf(smu, '*CLS');
fclose(smu);
delete(smu);
clear smu;


% Clear the instrument objects
%delete(instruments);
%clear instruments;

% Plot the I-V curve as a scatter plot
figure;
if dualMode
    numScans = numel(voltages) / (2 * numSteps);
    colors = lines(numScans);
    hold on;
    plot(voltages,current);
    grid on;
    % for i = 1:numScans
    %     startIdx = (i - 1) * 2 * numSteps + 1;
    %     endIdx = startIdx + 2 * numSteps - 1;
    %     scatter(voltages(startIdx:endIdx), current(startIdx:endIdx), 'filled', 'MarkerEdgeColor', colors(i, :));
    % end
    hold off;
    legend(arrayfun(@(n) sprintf('Dual Scan %d', n), 1:numScans, 'UniformOutput', false));
else
    plot(voltages, current);
    grid on;
end
xlabel('Voltage (V)');
ylabel('Current (A)');
title('I-V Characteristic');

% Save the figure as a PNG file
saveas(gcf, imageFilename);






