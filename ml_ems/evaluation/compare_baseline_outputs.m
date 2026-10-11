function summary = compare_baseline_outputs(reference,candidate,cfg)
names = cfg.scopes; count = numel(names);
max_error = nan(count,1); passed = false(count,1); reason = strings(count,1);
for k = 1:count
    try
        [ta,a] = read_scope(reference.(names{k}));
        [tb,b] = read_scope(candidate.(names{k}));
        assert(isequal(size(a),size(b)) && isequal(size(ta),size(tb)), ...
            'EMS:LogShape','Log dimensions differ.');
        assert(all(abs(ta-tb) <= cfg.time_tolerance), ...
            'EMS:LogTimes','Log times differ; no interpolation used for acceptance.');
        delta = abs(a-b);
        max_error(k) = max(delta,[],'all');
        passed(k) = all(delta <= cfg.absolute_tolerances(k) + ...
            cfg.relative_tolerance*abs(a),'all');
        if ~passed(k), reason(k) = "Signal difference exceeds tolerance."; end
    catch exception
        reason(k) = string(exception.message);
    end
end
summary = table(string(names(:)),max_error,cfg.absolute_tolerances(:), ...
    passed,reason,'VariableNames',{'Scope','MaxAbsoluteError','AbsoluteTolerance','Passed','Reason'});
end

function [t,y] = read_scope(s)
assert(isstruct(s) && isfield(s,'time') && isfield(s,'signals'), ...
    'EMS:MissingLog','Missing StructureWithTime Scope log.');
t = double(s.time(:)); y = [];
assert(numel(t)>1 && all(isfinite(t)) && all(diff(t)>0), ...
    'EMS:InvalidLogTime','Log times must be finite and strictly increasing.');
for j = 1:numel(s.signals)
    values = double(s.signals(j).values);
    assert(size(values,1)==numel(t),'EMS:LogOrientation','Unexpected Scope log orientation.');
    y = [y reshape(values,numel(t),[])]; %#ok<AGROW>
end
assert(~isempty(y) && all(isfinite(y),'all'), ...
    'EMS:InvalidLog','Missing, NaN or Inf signal data cannot pass parity.');
end
