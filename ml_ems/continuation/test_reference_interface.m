function report=test_reference_interface(project_root)
% Verify the unchanged default contract and experimental projection on captures.
if nargin<1, project_root=fileparts(fileparts(fileparts(mfilename('fullpath')))); end
addpath(fullfile(project_root,'ml_ems')); startup_ml_ems;
source=fullfile(project_root,'ml_ems','results', ...
 'stress300_m3_s20260906_20260908_171755_858325ba','run.mat');
loaded=load(source,'run'); records=loaded.run.runtime.constraint_replay;
times=cellfun(@(r)r.time,records); targets=[2.10 2.12 2.16 3.16 4.26];
errors=zeros(numel(records),1);
for j=1:numel(records)
 r=records{j}; cfg=loaded.run.cfg;
 cfg.control.Ts=r.dt; cfg.control.dynamic_torque_offset=r.offset;
 [~,~,d]=constraint_residual(r.safe,r.x,r.o,r.previous,cfg);
 errors(j)=max(abs([d.terms-r.terms d.command-r.command d.state-r.state]));
 assert(d.projection_command==d.command,'Default constraint contract changed.');
end
assert(all(isfinite(errors)) && max(errors)<=1e-6,'Captured residual regression.');
rows=zeros(numel(targets),5);
for j=1:numel(targets)
 [delta,k]=min(abs(times-targets(j))); assert(delta<1e-9,'Missing callback.');
 r=records{k}; cfg=loaded.run.cfg;
 cfg.control.Ts=r.dt; cfg.control.dynamic_torque_offset=r.offset;
 [~,strict_found]=project_qp(r.raw,r.x,r.o,r.previous,r.original,cfg);
 assert(strict_found==(j==1),'Strict feasibility differs from recorded audit.');
 cfg.control.reference_balance_soft=true;
 [q,found]=project_qp(r.raw,r.x,r.o,r.previous,r.original,cfg);
 assert(found && all(isfinite(q)),'Experimental QP failed.');
 [u,dg]=project_to_feasible_set(r.raw,r.x,r.o,r.previous,r.original,cfg);
 [~,~,d]=constraint_residual(u,r.x,r.o,r.previous,cfg);
 assert(all(isfinite(u)) && d.projection_command<=cfg.control.constraint_tolerance ...
  && dg.fallback_flag==0,'Experimental projection violates retained constraints.');
 assert(d.command>=d.projection_command,'Reference residual was hidden.');
 rows(j,:)=[r.time double(strict_found) d.projection_command d.command d.terms(11)];
end
report=struct('verified',true,'default_callbacks',numel(records), ...
 'default_max_error',max(errors),'rows',rows);
disp(array2table(rows,'VariableNames', ...
 {'time','strict_feasible','retained_violation','original_violation','reference_balance_term'}));
fprintf('REFERENCE_INTERFACE_TEST=PASS callbacks=%d\n',numel(records));
end
