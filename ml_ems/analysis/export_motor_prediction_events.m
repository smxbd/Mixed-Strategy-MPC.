function export_motor_prediction_events(base)
% Export saved diagnostic forecasts against fresh native physical observations.
status=jsondecode(fileread(fullfile(base,'validation_status.json')));
for k=1:numel(status.cases)
 saved=load(fullfile(status.cases(k).folder,'run.mat'),'run');r=saved.run;
 if isfield(r.runtime,'safety_inputs'),events=reconstruct_safety_events(r);else,events=r.runtime.infeasibility_events;end
 rows=zeros(0,12);reasons=cell(0,1);
 t=r.physical.time(:);o=r.physical.signals.values;
 for j=1:numel(events)
  ev=events(j);g=ev.guard.motor_guard;
  if ~g.forecast_valid,continue;end
  for h=1:numel(g.forecast_times_s)
   query=ev.time+g.forecast_times_s(h);if query>t(end)+1e-9,continue;end
   [err,idx]=min(abs(t-query));assert(err<1e-8,'Forecast endpoint must be a native sample.');
   pred=g.forecast_motor_rpm(:,h);actual=o(idx,6:7)';
   rows(end+1,:)=[ev.time query h pred' actual' (actual-pred)' ...
    g.static_infeasible ev.fallback_flag ev.command_violation]; %#ok<AGROW>
   reasons{end+1,1}=ev.infeasibility_reason; %#ok<AGROW>
  end
 end
 tableOut=array2table(rows,'VariableNames',{'callback_s','endpoint_s','endpoint_index', ...
  'predicted_A_rpm','predicted_B_rpm','actual_A_rpm','actual_B_rpm', ...
  'error_A_rpm','error_B_rpm','static_infeasible','fallback','command_residual'});
 tableOut.reason=reasons;writetable(tableOut,fullfile(base,[status.cases(k).cycle '_prediction_events.csv']));
end
end
