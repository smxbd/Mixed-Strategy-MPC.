function report = test_action_mapping(project_root)
%TEST_ACTION_MAPPING Validate action_from_power at representative boundaries.
if nargin < 1
    project_root = fileparts(fileparts(mfilename('fullpath')));
    project_root = fileparts(project_root);
end
root=fullfile(project_root,'ml_ems'); addpath(root,'-begin'); addpath(fullfile(root,'continuation'),'-begin'); startup_ml_ems;
cfg=continuation_config(project_root);
x=[300 .5 1 1 3200 4200 1600 800 2000 0 1000 -1000 1000 -1000 0 45 -45 0 0];
o=[30 30 60 950 0 1848 2664 1 15 .045 0 0 300 0 0 0 1000 -600 600 0]; original=existing_grid_ems(x);
stages=[1 3]; powers=[0 0.25*cfg.p.Pe_max 0.5*cfg.p.Pe_max cfg.p.Pe_max]; rows=[];
for st=stages
 x(4)=st;
 for k=1:numel(powers)
  u=action_from_power(powers(k),x,o,original,cfg);
  [M,off]=engine_load_relation(x,cfg); demand=M(2,:)*original(3:4)';
  recon=[M(1,:)*u(3:4)'+off, M(2,:)*u(3:4)'];
  rows(end+1,:)=[st powers(k) u recon(1)-u(2) recon(2)-demand]; %#ok<AGROW>
 end
end
report=struct('columns',{{'stage','engine_power_kW','ne','Te','TA','TB','engine_torque_error','demand_error'}},'rows',rows);
out=fullfile(cfg.paths.results,['action_mapping_test_' datestr(now,'yyyymmdd_HHMMSS')]); mkdir(out);
save(fullfile(out,'report.mat'),'report','cfg','-v7.3'); writematrix(rows,fullfile(out,'rows.csv'));
fprintf('ACTION_MAPPING_TEST=%s\n',out);
end
