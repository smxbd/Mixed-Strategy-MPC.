function test_core
cfg=experiment_config; p=cfg.p;
assert(abs(fuel_rate(p.ne_map(5),p.Te_map(5),p)-p.fuel_map(5,5)*p.ne_map(5)*p.Te_map(5)/9549/3600)<1e-10);
c=build_city200; validate_cycle(c); assert(numel(c.time)==2001);
a=perturb_cycle(c,123,'train',60); b=perturb_cycle(c,123,'train',60); assert(isequaln(a,b));
assert(isempty(intersect(cfg.training_seeds,cfg.validation_seeds)));
x=[300 .5 1 1 3200 4200 1600 800 2000 0 1000 -1000 1000 -1000 0 45 -45 0 0];
o=[30 30 60 950 0 1848 2664 1 15 .045 0 0 300 0 0 0 1000 -600 600 0];
original=existing_grid_ems(x); [u,d]=project_to_feasible_set([NaN Inf -Inf 0],x,o,original,original,cfg);
assert(all(isfinite(u))); [res,~]=constraint_residual(u,x,o,original,cfg);
assert((res<=cfg.control.constraint_tolerance)||d.hard_infeasible==1);
f=repmat([30 300 15 .045],cfg.control.horizon,1);
s1=RandStream('mt19937ar','Seed',7); s2=RandStream('mt19937ar','Seed',7);
[u1,w1]=cem_mpc(f,x,o,[],s1,cfg); [u2,w2]=cem_mpc(f,x,o,[],s2,cfg); assert(isequaln(u1,u2)&&isequaln(w1,w2));
disp('Core tests passed: fuel units, cycle contracts, deterministic perturbation/CEM, explicit infeasibility.');
end
