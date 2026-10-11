function c=perturb_cycle(base,seed,split,duration)
if nargin<4, duration=base.time(end); end
s=RandStream('mt19937ar','Seed',seed); c=base;
t=(0:.1:duration)'; scale=.65+.25*rand(s); warp=.7+.5*rand(s);
source_time=mod(t*warp,base.time(end));
c.time=t; c.v_ref=interp1(base.time,base.v_ref,source_time)*scale;
c.v_ref=max(0,min(115,c.v_ref+2*sin(t/(3+5*rand(s))).*(c.v_ref>5)));
c.road_resistance=(.025+.025*rand(s))+zeros(size(t));
c.grade=.025*sin(t/(8+12*rand(s))); c.steering_angle=zeros(size(t));
c.aux_power=10+20*rand(s)+8*(sin(t/(5+5*rand(s)))>0);
c.seed=seed; c.split=char(split); c.name=sprintf('%s_%s_%d',base.name,split,seed);
validate_cycle(c);
end
