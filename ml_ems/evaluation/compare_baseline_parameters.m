function summary = compare_baseline_parameters(reference,candidate,cfg)
names = fieldnames(reference);
passed = false(numel(names),1); max_error = nan(numel(names),1);
for k = 1:numel(names)
    key = names{k};
    if ~isfield(candidate,key), continue; end
    a = reference.(key); b = candidate.(key);
    if ~isequal(size(a),size(b)) || ~strcmp(class(a),class(b)), continue; end
    if isnumeric(a)
        if ~isequal(isnan(a),isnan(b)) || ~isequal(isinf(a),isinf(b)), continue; end
        if ~isequal(a(isinf(a)),b(isinf(b))), continue; end
        valid = isfinite(a);
        delta = abs(a(valid)-b(valid));
        scale = abs(a(valid));
        max_error(k) = max([0;delta(:)]);
        passed(k) = all(delta(:) <= cfg.parameter_abs_tolerance + ...
            cfg.parameter_rel_tolerance*scale(:));
    else
        passed(k) = isequaln(a,b);
    end
end
summary = table(string(names),max_error,passed, ...
    'VariableNames',{'Parameter','MaxAbsoluteError','Passed'});
end
