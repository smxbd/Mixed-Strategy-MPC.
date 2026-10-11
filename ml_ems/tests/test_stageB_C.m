function ok=test_stageB_C()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'),fullfile(root,'cycles'), ...
    fullfile(root,'controllers','ecms'),'-begin');
cfg=experiment_config(root); c=load_cycle('city200',cfg.cycles_dir);
assert(numel(c.time)==2001); assert(all(size(c.v_ref)==size(c.time)));
v=init_vehicle_params(); x=struct('Pe_com',100); [u,meta]=ecms_step(x,v);
assert(numel(u)==4 && all(isfinite(u)));
assert(strcmp(meta.controller_name,'ECMS baseline'));
% This checks interfaces only, not ECMS optimality or physical feasibility.
ok=true;
end
