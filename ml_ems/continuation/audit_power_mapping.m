function report = audit_power_mapping(project_root)
%AUDIT_POWER_MAPPING Check transmission inversion conditioning and map ranges.
if nargin < 1
    project_root = fileparts(fileparts(mfilename('fullpath')));
    project_root = fileparts(project_root);
end
root = fullfile(project_root,'ml_ems');
addpath(root,'-begin'); addpath(fullfile(root,'continuation'),'-begin');
startup_ml_ems;
cfg = continuation_config(project_root);
x = [300 .5 1 1 3200 4200 1600 800 2000 0 1000 -1000 1000 -1000 0 45 -45 0 0];
report = struct();
stage_ids = [1 3];
report.stages = repmat(struct('stage',[],'M',[],'motor_speed_rpm',[], ...
    'det',[],'cond',[],'rank',[],'singular_values',[]),1,numel(stage_ids));
for k = 1:numel(stage_ids)
    stage = stage_ids(k);
    xs=x; xs(4)=stage;
    [M,n] = transmission_relations(xs,cfg.p);
    report.stages(k).stage=stage; report.stages(k).M=M;
    report.stages(k).motor_speed_rpm=n;
    report.stages(k).det=det(M); report.stages(k).cond=cond(M);
    report.stages(k).rank=rank(M); report.stages(k).singular_values=svd(M);
end
report.engine_map_speed=cfg.p.ne_map;
report.engine_map_torque=cfg.p.Te_max_map;
report.motorA_speed=[min(cfg.p.nA_map) max(cfg.p.nA_map)];
report.motorA_torque=[min(cfg.p.TA_min_map) max(cfg.p.TA_max_map)];
out=fullfile(cfg.paths.results,['power_mapping_audit_' datestr(now,'yyyymmdd_HHMMSS')]); mkdir(out);
save(fullfile(out,'mapping_audit.mat'),'report','cfg','-v7.3');
fid=fopen(fullfile(out,'mapping_audit.txt'),'w'); fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true)); fclose(fid);
fprintf('POWER_MAPPING_AUDIT=%s\n',out);
end
