function ok = test_baseline_comparators()
cfg = baseline_validation_config();
a = struct('value',[1 NaN Inf -Inf]);
s = compare_baseline_parameters(a,a,cfg); assert(all(s.Passed));
b = a; b.value(2)=0; s=compare_baseline_parameters(a,b,cfg); assert(~all(s.Passed));
b = a; b.value(3)=-Inf; s=compare_baseline_parameters(a,b,cfg); assert(~all(s.Passed));
s=compare_baseline_parameters(a,struct(),cfg); assert(~all(s.Passed));
a = Simulink.SimulationOutput;
log = struct('time',[0;1;2],'signals',struct('values',[1 2;3 4;5 6]));
for k=1:numel(cfg.scopes), a.(cfg.scopes{k})=log; end
s=compare_baseline_outputs(a,a,cfg); assert(all(s.Passed));
bad=log; bad.signals.values(2,1)=NaN; b=a; b.(cfg.scopes{1})=bad;
s=compare_baseline_outputs(a,b,cfg); assert(~s.Passed(1));
bad=log; bad.time(2)=0; b=a; b.(cfg.scopes{1})=bad;
s=compare_baseline_outputs(a,b,cfg); assert(~s.Passed(1));
bad=log; bad.signals.values(2,1)=100; b=a; b.(cfg.scopes{1})=bad;
s=compare_baseline_outputs(a,b,cfg); assert(~s.Passed(1));
ok=true;
end
