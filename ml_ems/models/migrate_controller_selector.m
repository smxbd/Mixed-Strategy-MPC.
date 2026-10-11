function migrate_controller_selector(cfg)
% Update only the generated model. Keep an immutable pre-migration copy.
file=fullfile(cfg.paths.models,'EMT_ML.slx'); folder=create_run_directory(cfg,'selector_migration');
copyfile(file,fullfile(folder,'EMT_ML_before.slx')); load_system(file);
block='EMT_ML/Control Unit/Control/Power Distribution/Optimal Power Distribution/EMS Controller';
set_param(block,'Parameters','ems_runtime_config,controller_id');
ws=get_param('EMT_ML','ModelWorkspace'); assignin(ws,'ems_runtime_config',cfg); assignin(ws,'controller_id',1);
set_param('EMT_ML','SimulationCommand','update'); save_system('EMT_ML'); close_system('EMT_ML',0);
end
