function cycle=build_city200(varargin)
p=inputParser; addParameter(p,'Save',false); addParameter(p,'OutputDir',''); parse(p,varargin{:}); cycle.name='city200'; cycle.time=(0:0.1:200)'; t=cycle.time;
cycle.v_ref=0.*(t<11)+(3.75*t-41.25).*(t>=11&t<15)+15.*(t>=15&t<23)+(-3*t+84).*(t>=23&t<28)+(8*t/3-392/3).*(t>=49&t<61)+32.*(t>=61&t<85)+(-32*t/11+3072/11).*(t>=85&t<96)+(25*t/13-2925/13).*(t>=117&t<143)+50.*(t>=143&t<155)+(-15*t/8+2725/8).*(t>=155&t<163)+35.*(t>=163&t<176)+(-35*t/12+1645/3).*(t>=176&t<188);
cycle.road_resistance=0.045+zeros(size(t)); cycle.grade=zeros(size(t)); cycle.steering_angle=zeros(size(t)); cycle.aux_power=23+zeros(size(t)); if p.Results.Save, save(fullfile(p.Results.OutputDir,'city200.mat'),'cycle'); end
end
