function report = replay_constraint_terms(project_root)
%REPLAY_CONSTRAINT_TERMS Validate observable terms; torque offset is unlogged.
if nargin<1, project_root=fileparts(fileparts(mfilename('fullpath'))); project_root=fileparts(project_root); end
root=fullfile(project_root,'ml_ems','results');
addpath(fullfile(project_root,'ml_ems')); startup_ml_ems;
folders={'suburban400_m3_s20260906_20260908_152859_5c5fdbe7','stress300_m3_s20260906_20260908_153549_3a4ae2be'};
template=struct('folder','','samples',0,'matched',0,'state_max_error',NaN, ...
 'state_matches',false,'command_lower_bound_consistent',false, ...
 'full_replay_verified',false,'missing_terms',{{'torque_balance'}});
report=repmat(template,1,numel(folders));
out=tempname(root); mkdir(out);
names={'ne_lower','ne_upper','Te_lower','Te_upper','TA_lower','TA_upper', ...
 'TB_lower','TB_upper','Pb_lower','Pb_upper','torque_balance','rate_max'};
for k=1:numel(folders)
 a=load(fullfile(root,folders{k},'run.mat'),'run'); run=a.run; tr=run.trace; dg=run.runtime.diagnostics; c=run.cfg;
 ts=run.time(:); t=dg(:,1); dec=dg(:,2)>0;
 assert(size(tr,1)==numel(ts)&&size(tr,2)>=53,'Invalid trace dimensions.');
 assert(all(isfinite(ts))&&all(diff(ts)>=0),'Invalid trace time axis.');
 assert(all(isfinite(t))&&all(diff(t)>0),'Diagnostic times must increase.');
 [ts,ia]=unique(ts,'last'); tr=tr(ia,:);
 % Column 53 holds the last decision time, not the trace sample time.
 [matched,idx]=ismembertol(t,ts,1e-9,'DataScale',1);
 terms=NaN(numel(t),12); state=NaN(numel(t),1);
 interval=NaN(numel(t),1); rate_terms=NaN(numel(t),4);
 for j=find(matched)'
  row=tr(idx(j),:); x=row(1:19); o=row(20:39); u=row(44:47);
  local=c;
  if j==1
   previous=[min(x(6),max(x(7),row(40))) 0 0 0];
  else
   local.control.Ts=max(.002,t(j)-t(j-1));
   previous=NaN(1,4);
   if matched(j-1), previous=tr(idx(j-1),44:47); end
  end
  interval(j)=local.control.Ts;
  % Offset cannot be inferred from projected actions; discard term 11.
  local.control.dynamic_torque_offset=0;
  [~,~,detail]=constraint_residual(u,x,o,previous,local);
  terms(j,:)=detail.terms; terms(j,11)=NaN; state(j)=detail.state;
  rate_terms(j,:)=abs(u-previous)-local.control.rate*local.control.Ts;
  if any(~isfinite(previous)), terms(j,12)=NaN; end
 end
 known=[1:10 12]; valid=matched & all(isfinite(terms(:,known)),2);
 lower=NaN(numel(t),1); lower(valid)=max(0,max(terms(valid,known),[],2));
 err=abs(state-dg(:,4));
 report(k).folder=folders{k}; report(k).samples=numel(t); report(k).matched=sum(matched);
 if any(isfinite(err)), report(k).state_max_error=max(err,[],'omitnan'); end
 report(k).state_matches=all(matched)&&all(isfinite(err))&&all(err<=1e-6);
 report(k).command_lower_bound_consistent=all(valid)&&all(isfinite(dg(:,3)))&&all(lower<=dg(:,3)+1e-6);
 tab=array2table([t double(dec) double(matched) interval terms rate_terms state dg(:,4) err lower dg(:,3)], ...
  'VariableNames',[{'time','decision','matched','safety_dt'} names ...
  {'rate_ne_rpm','rate_Te_Nm','rate_TA_Nm','rate_TB_Nm','state_replayed','state_logged','state_error','command_lower_bound','command_logged'}]);
 writetable(tab,fullfile(out,[folders{k} '.csv']));
 save(fullfile(out,[folders{k} '.mat']),'tab','-v7.3');
end
save(fullfile(out,'summary.mat'),'report','-v7.3'); fprintf('CONSTRAINT_TERMS=%s\n',out);
fid=fopen(fullfile(out,'summary.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot open summary.json'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
disp(struct2table(report));
end
