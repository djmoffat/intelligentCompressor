classdef autocomp < audioPlugin
    properties (Constant)
    PluginInterface = audioPluginInterface( ...
        'PluginName','AutoComp', 'VendorName','FAST Project - C4DM', 'VendorVersion','0.1',... %'InputChannels',4,'OutputChannels',4,...
        'InputChannels',1, ...
        'OutputChannels',1, ...
        audioPluginParameter('bypass','DisplayName', 'bypass','Mapping', {'enum','on','off'}),...
        audioPluginParameter('threshold','DisplayName','threshold','Label','dB','Mapping',{'pow',1/3,-140,0}),...
        audioPluginParameter('ratio','DisplayName','ratio','Label','','Mapping',{'lin',1,10}),...
        audioPluginParameter('knee','DisplayName','knee','Label','','Mapping',{'lin',0,10}));
    end
    properties
        bypass = false;
        threshold = -10;
        ratio = 5;
        knee = 0;
    end
    properties% (Access = private)
        dRC;
        fs;
        time;
        
        attack = 0.05;
        release = 0.2;
        gain = 0;
%         Meter;
        crest;
        rms;
        buff = [];
        buffP = 1;
        BPM = 110;
        MyOnsetDetector;
        BPMCache;
        tailThresh = 20;
    end
    methods
        function obj = autocomp(obj)
            obj.fs = getSampleRate(obj);
            obj.buff = zeros(3*obj.fs,1);
            obj.dRC = compressor('SampleRate',obj.fs,'MakeUpGainMode','Auto');
            
            obj.MyOnsetDetector = audiopluginexample.private.OnsetDetector;
            obj.BPMCache = dsp.AsyncBuffer(100);
            setup(obj.BPMCache,0);
        end
        function out = process(plugin, in)
            in = in(:,1);
            out = in;
            fillBuffer(plugin, in);
            % SET PARAMS
            process(plugin.MyOnsetDetector,in);
            onsets = plugin.MyOnsetDetector.OnsetHistory;
%             plugin.BPM = tempoInduction(plugin,onsets);
            
            plugin.time = estimateTail(plugin, plugin.buff, plugin.buffP);
            plugin.crest = max(1,peak2rms(unfoldBuffer(plugin)));
            plugin.rms = rms(unfoldBuffer(plugin));
            processTunedPropertiesImpl(plugin);
            % APPLY COMPRESSION
            if(~plugin.bypass)
                out = step(plugin.dRC,in);
                
            end  
            % METERING
%             if ~isempty(plugin.Meter)
%                 attTime  = sprintf('%0.2f',plugin.dRC.AttackTime);
%                 relTime = sprintf('%0.2f',plugin.dRC.ReleaseTime);
%                 beatDisplay  = sprintf('%0.1f',plugin.BPM);
%                 update(plugin.Meter,attTime,relTime, beatDisplay);
%             end
        end
        function out = unfoldBuffer(obj)
            out = [obj.buff(obj.buffP:end);obj.buff(1:obj.buffP-1)];
        end
        function unfoldedBuffer = unfoldBuffer2(obj, buffer, pointer)
            unfoldedBuffer = [buffer(pointer:end);buffer(1:pointer-1)];
        end
        function fillBuffer(obj,in)
            blockSize = size(in,1);
            buffSize = size(obj.buff,1);
            
            while obj.buffP > buffSize
                obj.buffP = obj.buffP - buffSize;
            end 
            
            if obj.buffP+blockSize-1 > buffSize
                l1 = buffSize - obj.buffP+1;
                l2 = blockSize - l1;
                
                obj.buff(obj.buffP:end) = in(1:l1);
                obj.buff(1:l2) = in(l1+1:end);
                obj.buffP = obj.buffP + blockSize;
            else
                obj.buff(obj.buffP:obj.buffP+blockSize-1);
                obj.buffP = obj.buffP + blockSize;
            end
            
            if obj.buffP > buffSize
                    obj.buffP = obj.buffP - buffSize;
            end   
        end
        
        function time = estimateTail(plugin, buffer_, pointer)
            time = 0.1;
            buffer = unfoldBuffer2(plugin, buffer_, pointer);
            magWin = mag2db(hilbert(buffer));
            window = (magWin-max(magWin)) > plugin.tailThresh;
            f1 = find(diff(window)==-1);
            f2 = find(diff(window)==1);
            sizeDiff = size(f1,1) - size(f2,1);
            if sizeDiff > 0
                f1 = f1(1:end-1);
            elseif sizeDiff < 0
                f2 = f2(2:end);
            end
            runs_zeros = f1-f2;
            winLens = runs_zeros(runs_zeros>100);
            release_samples = mean(winLens);
            releaseTime = release_samples/plugin.fs;
            if releaseTime > 0.1
                time = releaseTime;
            end
        end
        function processTunedPropertiesImpl(obj)
            obj.dRC.Threshold = obj.rms;
            obj.dRC.Ratio = obj.crest;
            obj.dRC.AttackTime = obj.time;
            obj.dRC.ReleaseTime = max(0,60/obj.BPM - obj.time);
            kneeRatio = obj.dRC.AttackTime / obj.dRC.ReleaseTime;
            obj.dRC.KneeWidth = kneeRatio * obj.crest;
%             obj.dRC.AttackTime = (1.6*obj.time^2 + 3.5*obj.time + 3.0)/20;
%             obj.dRC.ReleaseTime = max((1.7*obj.time^2 - 4.4*obj.time + 4)/10,obj.dRC.AttackTime+0.005);
        end
        function visualize(plugin)
            if ~isempty(plugin.Meter) && isvalid(plugin.Meter) && isFigureValid(plugin.Meter)
                show(plugin.Meter);
            else
                plugin.Meter = audiopluginexample.private.MeterUI('Timing Meter','Attack Time','Release Time', 'BPM');
            end
        end
        function reset(obj)
            obj.fs = getSampleRate(obj);
            obj.dRC = compressor('SampleRate',obj.fs,'MakeUpGainMode','Auto');
            setSampleRate(obj.MyOnsetDetector,getSampleRate(obj))
            reset(obj.MyOnsetDetector)
            reset(obj.BPMCache);
            obj.buff = zeros(3*obj.fs,1);
            % Reset visualization
%             if isempty(coder.target) && ~isempty(obj.Meter) && isFigureValid(obj.Meter)
%             	reset(obj.Meter)
%             end
        end
    end
    methods (Access = private)
        function BPM = tempoInduction(plugin,onsets)         
            % Locate valid onsets
            validLocs = ~isnan(onsets);
            
            if sum(validLocs) > 10

                % Convert onsets locations in time to period
                period = diff(onsets(validLocs));
                
                % Take mean of inner quartiles
                periodSorted = sort(period);
                lower25 = round(numel(periodSorted)*0.25);
                upper25 = round(numel(periodSorted)*0.75);
                periodInnerQuartiles = periodSorted(lower25:upper25);
                avgPeriod = mean(periodInnerQuartiles);
                
                % Convert period to BPM
                freq       = 1/avgPeriod;
                BPMCurrent = 60*freq;
                
                % Write current BPM to cache
                write(plugin.BPMCache,BPMCurrent);
                
                % Get current and past 99 BPM decisions and average
                allBPM = read(plugin.BPMCache,100,99);
                BPM = round(mean(allBPM(allBPM~=0)));
            else
                % If no new BPM decision, output average of past 100 BPM decisions.
                allBPM = read(plugin.BPMCache,100,100);
                BPM = round(mean(allBPM(allBPM~=0)));
            end

        end
        
    end
end