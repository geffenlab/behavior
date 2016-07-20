function Training(params)
KbName('UnifyKeyNames');
fileGoto = [params.fn '_training.txt'];

comport = 'COM6';

%Load corresponding Arduino sketch
hexPath = [params.hex filesep 'Training.ino.hex'];
[status, cmdOut] = loadArduinoSketch(params.comport,hexPath);
cmdOut

% Open text file
fn = fopen(fileGoto,'w');


%Send setup() variables to arduino
varvect = [params.holdD params.rewardD params.respD params.timeoutD];
fprintf(s,'%f %f %f %f ',varvect);

%Variables
selectStimuli       = [0]; %multiples of 0.1s
t                   = 0;
ts                  = {};
timeoutState        = 0;
rewardState         = 0;

% modify params to reflect actual stimuli used
params.dbSteps = params.dbSteps([1 end]);
params.dB = params.dB([1 end]);
params.toneA = params.toneA([1 end]);
params.noiseD = params.noiseD(1);

% Make stimuli
Fs = params.fsActual;
f = params.toneF;
sd = params.toneD;
nd = params.noiseD;
samp = params.toneA;
namp = params.noiseA;
rd = params.rampD;


% make noise
[noise,events] = makeStimFilt(Fs,f,sd,nd,0,namp,rd,FILT.filt);
% make signals and add to noise
for i = 1:length(samp)
    stim{i} = makeStimFilt(Fs,f,sd,nd,samp(i),namp,rd,FILT.filt);
end

disp('Press any key to start.');
pause;


taskState = 0;
disp(' ');
lickCount = [];
%%Task
while 1
    
    switch taskState
        
        case 0 %proceed when arduino signals (2s no licks)
            t = t + 1;
            lickCount = 0;
            
            if t ~= 1
                fprintf(' Waiting %g seconds with no licks to proceed...\n',patientWait)
            end
            
            while 1
                if s.BytesAvailable > 0
                    ardOutput = fscanf(s,'%c');
                    ts(t).trialstart = str2num(ardOutput(1:end-2));
                    taskState = 1;
                    break
                end
            end
            
        case 1 %generate random stimuli
            trialChoice(t) = rand < 0.5;
            if t > 3 && range(trialChoice(end-3:end-1)) == 0
                trialChoice(t) = ~trialChoice(t-1);
            end
            if ~trialChoice(t) %Noise, stim{1}
                fprintf(s,'%i',0);
                queueOutputData(n,[noise'*10 events']);
                startBackground(n)
                trialType(t) = 0;
                disp(sprintf('%03d 0 %i %s NOISE_TRIAL',t,trialType(t),ardOutput(1:end-2)));
                taskState = 2;
            else  %Signal, stim{2}
                fprintf(s,'%i',1);
                queueOutputData(n,[stim{1}'*10 events']);
                startBackground(n)
                trialType(t) = 1;
                disp(sprintf('%03d 0 %i %s SIGNAL_TRIAL',t,trialType(t),ardOutput(1:end-2)));
                taskState = 2;
            end
            
        case 2 %Interpret Arduino Output for Display
            ardOutput = fscanf(s,'%c');
            if ardOutput(1) == 'L'
                disp(sprintf('%03d 1 %i %s LICK',t,trialType(t),ardOutput(2:end-2)))
                lickCount = lickCount + 1;
                ts(t).lick(lickCount) = str2double(ardOutput(2:end-2));
                fprintf(fn,'%03d %i %010d LICK\n',t,trialType(t),ts(t).lick(lickCount));
            elseif ardOutput(1) == 'R'
                disp(sprintf('%03d 1 %i %s REWARD',t,trialType(t),ardOutput(2:end-2)))
                ts(t).rewardstart = str2num(ardOutput(2:end-2));
                rewardState = 1;
                fprintf(fn,'%03d %i %010d REWARD_START\n',t,trialType(t),ts(t).rewardstart);
            elseif ardOutput(1) == 'W'
                ts(t).rewardend = str2num(ardOutput(2:end-2));
                fprintf(fn,'%03d %i %010d REWARD_END\n',t,trialType(t),ts(t).rewardend);
            elseif ardOutput(1) == 'T'
                if timeoutState ~= 1
                    disp(sprintf('%03d 1 %i %s TIMEOUT',t,trialType(t),ardOutput(2:end-2)))
                    timeoutState = 1;
                end
                ts(t).timeoutstart = str2num(ardOutput(2:end-2));
                fprintf(fn,'%03d %i %010d TIMEOUT_START\n',t,trialType(t),ts(t).timeoutstart);
            elseif ardOutput(1) == 'S'
                ts(t).stimstart = str2num(ardOutput(2:end-2));
                fprintf(fn,'%03d %i %010d STIM_START\n',t,trialType(t),ts(t).stimstart);
            elseif ardOutput(1) == 'O'
                ts(t).stimend = str2num(ardOutput(2:end-2));
                ts(t).respstart = str2num(ardOutput(2:end-2));
                fprintf(fn,'%03d %i %010d STIM_END_RESP_START\n',t,trialType(t),ts(t).stimend);
            elseif ardOutput(1) == 'C'
                fprintf('    %g Lick(s) Detected...',lickCount)
                ts(t).respend = str2num(ardOutput(2:end-2));
                fprintf(fn,'%03d %i %010d RESP_END\n',t,trialType(t),ts(t).respend);
                taskState = 3;
            end
            
        case 3 %Timeout, Reward
            while timeoutState == 1
                ardOutput = fscanf(s,'%c');
                if ardOutput(1) == 'T'
                    ts(t).timeoutstart = str2num(ardOutput(2:end-2));
                    fprintf(fn,'%03d %i %010d TIMEOUT_START\n',t,trialType(t),ts(t).timeoutstart);
                elseif ardOutput(1) == 'Q'
                    ts(t).timeoutend = str2num(ardOutput(2:end-2));
                    fprintf(fn,'%03d %i %010d TIMEOUT_END\n',t,trialType(t),ts(t).timeoutend);
                    timeoutState = 0;
                    break
                end
            end
            while rewardState == 1
                ardOutput = fscanf(s,'%c');
                if ardOutput(1) == 'W'
                    ts(t).rewardend = str2num(ardOutput(2:end-2));
                    fprintf(fn,'%03d %i %010d REWARD_END\n',t,trialType(t),ts(t).rewardend);
                    rewardState = 0;
                    break
                end
            end
            taskState = 4;
            
        case 4 %End Trial
            if n.IsRunning == 1
                stop(n)
            end
            taskState = 0;
    end
    
    [~,~,keyCode] = KbCheck;
    if sum(keyCode) == 1
        if strcmp(KbName(keyCode),'ESCAPE');
            fprintf(fn,'USER_EXIT');
            disp('User exit...');
            break
        end
    end
    if t > 1000
        fprintf(fn,'MAX_TRIALS');
        disp('Max trials reached...');
        break;
    end
end

save(sprintf('%s\\%03d_%s.mat',datDir,mouseID,time),'ts','trialType');
[f,pC] = plotPerformance(ts,trialType);
fprintf('%g%% CORRECT\n',pC*100);
print(f,sprintf('%s\\%03d_%s_plot.png',datDir,mouseID,time),'-dpng','-r300');
pause
% save(sprintf('%s_%d_TimeStamps.mat',time,mouseID),'ts');
% save(sprintf('%s_%d_trialTypes.mat',time,mouseID),'trialType');
delete(s)
close('all')
clear all
