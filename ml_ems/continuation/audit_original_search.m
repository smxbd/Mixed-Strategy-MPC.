function report = audit_original_search(project_root)
% Replay archived inputs through original source with branch-only tracing.
if nargin<1
    project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
root=fullfile(project_root,'ml_ems');
source=fullfile(root,'analysis','evidence','optimization_original.m');
capture=fullfile(root,'results', ...
    'stress300_m3_s20260906_20260908_171755_858325ba','run.mat');
loaded=load(capture,'run');
records=loaded.run.runtime.constraint_replay;
times=cellfun(@(r)r.time,records);
folder=tempname(fullfile(root,'results')); mkdir(folder);
copyfile(source,fullfile(folder,'optimization_original.m'));
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'audit_original_search.m'));
lines=regexp(fileread(source),'\r\n|\n|\r','split');
plain=lines; plain{1}='function y = ems_original_plain(u)';
write_text(fullfile(folder,'ems_original_plain.m'),strjoin(plain,newline));
traced={'function [y, audit] = ems_original_trace(u)', ...
    'audit_events=zeros(0,8); audit_phase=1;'};
phase=2; winners=0; defaults=0;
for n=2:numel(lines)
    line=lines{n}; trimmed=strtrim(line);
    % Only unindented guards are the four global fallback passes.
    if strcmp(line,'if NN_Te==0')
        phase=phase+1;
        traced{end+1}=sprintf('audit_phase=%d;',phase); %#ok<AGROW>
    end
    if strcmp(trimmed,'if NN_PN1(i,j)==0')
        traced{end+1}='audit_phase=2;'; %#ok<AGROW>
    end
    if phase==2 && startsWith(line,'for i=1:L_Te')
        traced{end+1}=line; %#ok<AGROW>
        traced{end+1}='audit_phase=1;'; %#ok<AGROW>
        continue;
    end
    traced{end+1}=line; %#ok<AGROW>
    if strcmp(trimmed,'Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);')
        winners=winners+1;
        traced{end+1}= ...
            'audit_events(end+1,:)=[audit_phase 1 i j J0 Te_ref TA_ref TB_ref];'; %#ok<AGROW>
    elseif phase>=4 && (strcmp(trimmed,'Te_ref=Te_max;') || strcmp(trimmed,'Te_ref=Te_min;'))
        defaults=defaults+1;
        traced{end+1}= ...
            'audit_events(end+1,:)=[audit_phase 0 i NaN J0 Te_ref TA_ref TB_ref];'; %#ok<AGROW>
    end
end
assert(phase==6 && winners==6 && defaults==4, ...
    'Original source layout changed; review instrumentation before replay.');
traced{end+1}=['audit=struct(''events'',audit_events,''ne_ref_internal'',ne_ref0+' ...
    '(pedal>0)*sd_ne,''dne'',dne,''speed_factor'',x_ne,''engine_grid'',Te,' ...
    '''NN_Te'',NN_Te,''NN_PN0_count'',sum(NN_PN0(:)),''NN_ne_count'',sum(NN_ne(:)),' ...
    '''NN_PN1_count'',sum(NN_PN1(:)),''effective_motor_limits'',[TA_min TA_max TB_min TB_max]);'];
write_text(fullfile(folder,'ems_original_trace.m'),strjoin(traced,newline));
old_path=path; cleanup=onCleanup(@()path(old_path)); %#ok<NASGU>
addpath(folder,'-begin');
clear ems_original_plain ems_original_trace
targets=[2.08 2.10 2.12 2.14 2.16 3.16 4.26];
rows=cell(numel(targets),1);
for k=1:numel(targets)
    [delta,index]=min(abs(times-targets(k)));
    assert(delta<1e-9,'Requested callback missing.');
    r=records{index};
    plain_y=ems_original_plain(r.x);
    [trace_y,audit]=ems_original_trace(r.x);
    errors=[max(abs(plain_y(:)-r.original(:))),max(abs(plain_y(:)-trace_y(:)))];
    rows{k}=struct('time',r.time,'input',r.x,'captured',r.original, ...
        'plain',plain_y,'traced',trace_y,'capture_error',errors(1), ...
        'instrumentation_error',errors(2),'verified',all(isfinite(errors)) && ...
        all(errors<=1e-6),'audit',audit);
end
report=struct('folder',folder,'capture',capture,'source',source, ...
    'verified',all(cellfun(@(r)r.verified,rows)),'rows',{rows}, ...
    'event_columns',{{'phase','kind_1_winner_0_default','i','j','J0','Te','TA','TB'}}, ...
    'phases',{{'strict','relaxed_PN1','NN_ne_power_fallback', ...
    'PN0_speed_default','speed_only_search','final_power_default'}});
save(fullfile(folder,'original_search.mat'),'report');
write_text(fullfile(folder,'original_search.json'),jsonencode(report,'PrettyPrint',true));
fprintf('ORIGINAL_SEARCH_AUDIT=%s\n',folder);
for k=1:numel(rows)
    r=rows{k};
    fprintf('t=%.2f verified=%d Te=%.9g dne=%.9g NN_Te=%d\n', ...
        r.time,r.verified,r.traced(2),r.audit.dne,r.audit.NN_Te);
    disp(array2table(r.audit.events,'VariableNames',report.event_columns));
end
assert(report.verified,'EMS:OriginalReplayMismatch', ...
    'Output parity failed; do not infer the runtime branch from this replay.');
end

function write_text(filename,value)
fid=fopen(filename,'w','n','UTF-8');
assert(fid>=0,'Cannot write diagnostic artifact.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',value);
end
