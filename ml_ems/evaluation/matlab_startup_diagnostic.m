function diagnostic=matlab_startup_diagnostic()
diagnostic=struct('matlab_release',version,'tempdir',tempdir,'pwd',pwd,'timestamp',datestr(now,30));
end
