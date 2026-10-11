function cycle=build_suburban400(varargin)
p=inputParser; addParameter(p,'Save',false); addParameter(p,'OutputDir',''); parse(p,varargin{:}); cycle.name='suburban400'; cycle.time=(0:0.1:400)'; t=cycle.time;
cycle.v_ref=7*t/4.*(t<40)+70.*(t>=40&t<91)+(-2.5*t+297.5).*(t>=91&t<99)+50.*(t>=99&t<168)+(20*t/13-2710/13).*(t>=168&t<181)+70.*(t>=181&t<231)+(6*t/7-128).*(t>=231&t<266)+100.*(t>=266&t<296)+(t-196).*(t>=296&t<316)+120.*(t>=316&t<326)+(-60*t/37+24000/37).*(t>=326);
cycle.road_resistance=0.045+zeros(size(t)); cycle.grade=zeros(size(t)); cycle.steering_angle=zeros(size(t)); cycle.aux_power=23+zeros(size(t)); if p.Results.Save, save(fullfile(p.Results.OutputDir,'suburban400.mat'),'cycle'); end
end
