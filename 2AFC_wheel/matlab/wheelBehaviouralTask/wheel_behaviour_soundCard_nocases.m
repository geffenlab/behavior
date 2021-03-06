% Behaviour task with wheel response
function wheel_behaviour_soundCard_nocases
% run wheel_interruptor_test

InitializePsychSound(1);
fs=192000;
sc = PsychPortAudio('Open', [], 1, 3, fs, 3); %'Open' [, deviceid][, mode][, reqlatencyclass][, freq][, channels]
% Channel 1 is left speaker, 2 is right speaker and 3 is events
status = PsychPortAudio('GetStatus', sc);
fs = status.SampleRate; % check sample rate
s=setupSerial('COM5'); % windows

% Initialise variables:
trialNumber = 0;
newTrial = 1;
KbName('UnifyKeyNames');

fid = fopen('data.txt','a+');

%% LOAD SOUND STIMULI AND TELL ARDUINO TRIAL TYPE

tt = [];
cnt = 0;
flag = 0;
while ~flag
    out = serialRead(s);
       
    if strcmp(out,'start')
        
        if newTrial==1 %   send new stimulus to sound card
            correctionTrial=0;
            trialType = 1;
        else %   continue with same sound
            correctionTrial=1;
            trialType = 1;
        end
        
        % Increase trial number
        trialNumber=trialNumber+1;
        disp(['Trial: ' num2str(trialNumber)]);
        
        % send trial type to arduino
        fprintf(s,'%s',trialType); % 1=left 2=right
        
        % Check it was received
        ttr = serialRead(s);
        
        %         fscanf(s,'%s')
        disp(['Trial type received: ' ttr])
        
    elseif strcmp(out,'mouseStill')
        % WAIT FOR MOUSE TO STOP MOVING WHEEL
        % wait for one second for the mouse to keep the wheel still...
        
        % Wait for arduino to send data
        mouseStillTime = serialRead(s);
        disp(['mouse still for 1 second: ' num2str(mouseStillTime)])
        
        % PRESENT THE SOUND AND RECEIVE SOUND OFFSET
        
        % PRESENT SOUND HERE
        outputSignal1 = [rand(fs*3,1)/10; zeros(100,1)]';
        outputSignal2 = zeros(1,length(outputSignal1));
        outputSignal3 = [ones(50,1)*3; zeros(fs*3,1); ones(50,1)*3]';
        PsychPortAudio('FillBuffer', sc, [outputSignal1;outputSignal2;outputSignal3]);
        
        % Start presentation
        t1 = PsychPortAudio('Start', sc, 1); % 'Start', pahandle [, repetitions=1] [, when=0] [, waitForStart=0]
        
        % Wait for arduino to send info
        soundOnset = serialRead(s);
        disp(['sound onset received: ' num2str(soundOnset)])
        
        soundOffset = serialRead(s);
        disp(['sound offset received: ' num2str(soundOffset)])
%         disp(['Difference: ' num2str(soundOffset-soundOnset)])
        %         fscanf(s,'%s')
        
        % RECEIVE INPUT FROM ARDUINO WITH RESPONSE TIME AND IF TRIAL CORRECT OR NOT
    elseif strcmp(out,'waitForResp')
        
        responseTime = serialRead(s);
        responseOutcome = serialRead(s);
        disp(['Response time = ' num2str(responseTime)]);
        disp(['Correct? ' num2str(responseOutcome)]);
        
        if responseOutcome==1
            newTrial = 1;
        else
            newTrial = 0;
        end
        
        logWheelTrial_WL(fid,trialNumber, correctionTrial, trialType, str2double(mouseStillTime),...
            str2double(soundOnset),str2double(soundOffset),str2double(responseTime),str2double(responseOutcome))
    end
    
    % Exit statement
    [~,~,keyCode] = KbCheck;
    if sum(keyCode) == 1
        if strcmp(KbName(keyCode),'ESCAPE') || cnt > 10
            flag = 1;
        end
    end
end

delete(instrfindall)
fclose(fid)
clear all



