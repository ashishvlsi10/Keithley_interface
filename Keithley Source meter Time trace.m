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
headers = {'Time (s)', 'Current (A)', 'Voltage Channel A (V)', 'Voltage Channel B (V)'};

% Ask user for the total time duration for the measurement
totalTime = input('Enter the total time duration for the measurement (in seconds): ');

% Set numSteps equal to the given time duration
numSteps = totalTime;

% Calculate the time interval between steps
timeInterval = totalTime / (numSteps - 1);

% Generate time vector
time = linspace(0, totalTime, numSteps);

% Set the bias voltage values for Channel A and Channel B
voltageA = 0.1; % Bias voltage for Channel A
voltageB = 0.4; % Bias voltage for Channel B

% Set channel A for constant bias voltage
fprintf(smu, 'smua.source.func = smua.OUTPUT_DCVOLTS');
fprintf(smu, 'smua.source.autorangev = smua.AUTORANGE_ON');
fprintf(smu, 'smua.measure.nplc = 1'); % set nplc 1
fprintf(smu, 'smua.source.levelv = %f', voltageA); % Set the bias voltage to 0.1V

% Set channel B for constant voltage
fprintf(smu, 'smub.source.func = smub.OUTPUT_DCVOLTS');
fprintf(smu, 'smub.source.levelv = %f', voltageB); % Set the bias voltage to 0.4V
fprintf(smu, 'smub.sense = smua.SENSE_LOCAL');
fprintf(smu, 'smub.measure.nplc = 1');
fprintf(smu, 'smub.measure.autozero = smub.AUTOZERO_ONCE');
fprintf(smu, 'smub.measure.rangei = pulseLimit');
fprintf(smu, 'smub.nvbuffer1.clear()');

% Enable output
fprintf(smu, 'smua.source.output = smua.OUTPUT_ON');
fprintf(smu, 'smub.source.output = smub.OUTPUT_ON');

current = zeros(1, numel(time));

% Initialize live plot
figure;
h = plot(time, current, '-o');
xlabel('Time (s)');
ylabel('Current (A)');
title(['Current vs Time - ' filename]);
grid on;

for i = 1:numel(time)
    % Measure the current on Channel A
    fprintf(smu, 'smua.measure.i(smua.nvbuffer1)');
    
    % Read the measured current
    current_str = query(smu, 'printbuffer(1, smua.nvbuffer1.n, smua.nvbuffer1.readings)');
    current(i) = str2double(current_str);
    
    % Display the time and current
    fprintf('Time: %.2f s, Current: %.9f A\n', time(i), current(i));
    
    % Update the live plot
    set(h, 'YData', current);
    drawnow;
    
    % Wait for the next time step
    pause(timeInterval);
end

% Save data to Excel
dataTable = table(time', current', repmat(voltageA, numSteps, 1), repmat(voltageB, numSteps, 1), 'VariableNames', headers);
writetable(dataTable, excelFilename);

% Routine for closing switch matrix
fprintf(smu, '*RST');
fprintf(smu, '*CLS');
fclose(smu);
delete(smu);
clear smu;

% Save the figure as a PNG file
saveas(gcf, imageFilename);
