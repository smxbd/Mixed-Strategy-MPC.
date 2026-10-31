function verify_reference_scope_parity(base)
files=dir(fullfile(base,'parity','*','parity.csv'));allPassed=true;rows=struct([]);
for k=1:numel(files)
 folder=files(k).folder;
 a=load(fullfile(folder,'reference','simulation.mat'),'out');
 b=load(fullfile(folder,'Existing','simulation.mat'),'out');
 names=a.out.who;result=struct([]);
 for j=1:numel(names)
  value=a.out.get(names{j});
  if ~isstruct(value)||~isfield(value,'time')||~isfield(value,'signals'),continue;end
  other=b.out.get(names{j});
  [t,x]=flatten_scope(value);[u,y]=flatten_scope(other);
  equalTimes=isequal(t,u);equalShape=isequal(size(x),size(y));
  err=Inf;passed=false;
  if equalTimes&&equalShape&&all(isfinite(x),'all')&&all(isfinite(y),'all')
   delta=abs(x-y);err=max(delta,[],'all');passed=all(delta<=1e-8+1e-10*abs(x),'all');
  end
  row=struct('signal',names{j},'samples',numel(t),'columns',size(x,2), ...
   'times_equal',equalTimes,'max_absolute_error',err,'passed',passed);
  result=[result row]; %#ok<AGROW>
 end
 writetable(struct2table(result),fullfile(folder,'all_scope_parity.csv'));
 passed=all([result.passed]);allPassed=allPassed&&passed;
 [~,name]=fileparts(folder);rows=[rows struct('cycle',name,'signals',numel(result),'passed',passed)]; %#ok<AGROW>
end
report=struct('all_passed',allPassed,'cycles',rows);
fid=fopen(fullfile(base,'all_scope_parity_status.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));fclose(fid);
assert(numel(rows)==4&&allPassed,'EMS:ScopeParityFailed','All-scope full-cycle parity failed or incomplete.');
end
function [t,x]=flatten_scope(log)
t=double(log.time(:));x=[];
for k=1:numel(log.signals)
 v=double(log.signals(k).values);
 if size(v,1)==numel(t),v=reshape(v,numel(t),[]);
 elseif size(v,ndims(v))==numel(t),v=reshape(permute(v,[ndims(v) 1:ndims(v)-1]),numel(t),[]);
 else,error('EMS:ScopeShape','Unrecognized scope orientation.');end
 x=[x v]; %#ok<AGROW>
end
end
