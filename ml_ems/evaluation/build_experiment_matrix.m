function jobs=build_experiment_matrix(cfg,kind)
cycles={'city200','suburban400','stress300'}; jobs=struct('cycle',{},'method',{},'seed',{},'label',{},'cfg',{});
switch char(kind)
 case 'focus'
  for method=cfg.methods
   jobs(end+1)=job('city200',method,cfg.seed,'focus',cfg); %#ok<AGROW>
  end
 case 'main'
  for c=1:3, for method=1:8
   local=cfg; jobs(end+1)=job(cycles{c},method,1,'main',local); %#ok<AGROW>
  end, end
 case 'ablation'
  labels={'without_fuel_map','without_terminal_SOC','without_uncertainty','without_history','LSTM_replacement','risk_sensitive'};
  for c=1:3, for k=1:6
   local=cfg; method=7;
   switch k
    case 1, local.control.no_fuel_map=true;
    case 2, local.control.no_terminal_soc=true;
    case 3, method=8; local.control.no_uncertainty=true;
    case 4, local.control.no_history=true;
    case 5, method=6;
    case 6, method=8;
   end
   jobs(end+1)=job(cycles{c},method,1,labels{k},local); %#ok<AGROW>
  end, end
 case 'robustness'
  for c=1:3, for method=5:8, for seed=cfg.seeds
   jobs(end+1)=job(cycles{c},method,seed,'seed_repeat',cfg); %#ok<AGROW>
  end, end, end
 case 'generalization'
  for c=1:3, for method=1:8
   local=cfg; local.mass_scale=1.1; local.initial_soc_percent=50;
   cy=load_cycle(cycles{c}); cy.road_resistance=cy.road_resistance*1.2; cy.grade=cy.grade+.02; cy.aux_power=cy.aux_power+10;
   cy.name=[cy.name '_unseen']; cy.split='generalization';
   jobs(end+1)=job(cy,method,301,'mass_SOC_load_grade_shift',local); %#ok<AGROW>
  end, end
 otherwise, error('Unknown experiment group');
end
end
function j=job(cycle,method,seed,label,cfg)
j=struct('cycle',cycle,'method',method,'seed',seed,'label',label,'cfg',cfg);
end
