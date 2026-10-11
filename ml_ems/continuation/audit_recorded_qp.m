function report = audit_recorded_qp(project_root)
% Inspect captured callbacks without running Simulink or changing constraints.
if nargin<1
 project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(fullfile(project_root,'ml_ems')); startup_ml_ems;
source=fullfile(project_root,'ml_ems','results', ...
 'stress300_m3_s20260906_20260908_171755_858325ba','run.mat');
loaded=load(source,'run'); run=loaded.run;
records=run.runtime.constraint_replay;
times=cellfun(@(r)r.time,records);
targets=[2.10 2.12 2.16 3.16 4.26];
report=cell(numel(targets),1);
options=optimoptions('linprog','Display','none');
for k=1:numel(targets)
 [delta,j]=min(abs(times-targets(k)));
 assert(delta<1e-9,'Requested callback missing.');
 r=records{j}; cfg=run.cfg;
 cfg.control.Ts=r.dt; cfg.control.dynamic_torque_offset=r.offset;
 [u,found,a]=project_qp(r.raw,r.x,r.o,r.previous,r.original,cfg);
 result=struct('time',r.time,'stage',r.x(4),'ZD',r.x(3), ...
  'dt',r.dt,'offset',r.offset,'original',r.original,'previous',r.previous, ...
  'executed',r.safe,'fallback_logged',r.fallback,'qp_found',found, ...
  'qp_candidate',u,'audit',a,'verdict','unresolved');
 % Box bounds alone provide an exact contradiction when lower exceeds upper.
 if a.bound_conflict
  result.verdict='infeasible_box_bounds';
 else
  validated=false; all_infeasible=true;
  for q=1:numel(a.regions)
   region=a.regions{q};
   [z,~,flag]=linprog(zeros(4,1),region.A.*a.scale,region.b,[],[], ...
    a.lower./a.scale,a.upper./a.scale,options);
   region.lp_exitflag=flag; region.lp_candidate=[];
   region.lp_command_residual=NaN; region.lp_validated=false;
   if ~isempty(z)&&all(isfinite(z))
    candidate=z'.*a.scale;
    [~,~,detail]=constraint_residual(candidate,r.x,r.o,r.previous,cfg);
    region.lp_candidate=candidate;
    region.lp_command_residual=detail.command;
    linear_error=max([0;region.A*candidate'-region.b]);
    region.lp_validated=flag>0&&isfinite(detail.command)&& ...
     detail.command<=cfg.control.constraint_tolerance&&linear_error<=1e-6;
   end
   validated=validated||region.lp_validated;
   all_infeasible=all_infeasible&&(flag==-2);
   result.audit.regions{q}=region;
  end
  if found
   result.verdict='qp_feasible';
  elseif validated
   result.verdict='lp_feasible_qp_missed';
  elseif all_infeasible
   result.verdict='lp_reports_all_regions_infeasible';
  end
 end
 report{k}=result;
end
out=tempname(fullfile(project_root,'ml_ems','results')); mkdir(out);
save(fullfile(out,'audit.mat'),'report','source','targets','-v7.3');
copyfile(which('project_qp'),fullfile(out,'project_qp.m'));
copyfile([mfilename('fullpath') '.m'],fullfile(out,'audit_recorded_qp.m'));
fid=fopen(fullfile(out,'audit.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot open audit.json'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fprintf('RECORDED_QP_AUDIT=%s\n',out);
for k=1:numel(report), fprintf('t=%.2f %s\n',report{k}.time,report{k}.verdict); end
end
