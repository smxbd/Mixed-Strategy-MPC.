function ems_sfun(block)
block.NumDialogPrms=1+contains(get_param(block.BlockHandle,'Parameters'),',controller_id');
block.NumInputPorts=3; block.NumOutputPorts=2;
block.SetPreCompInpPortInfoToDynamic; block.SetPreCompOutPortInfoToDynamic;
width=[19 20 4];
for k=1:3, block.InputPort(k).Dimensions=width(k); block.InputPort(k).DatatypeID=0; block.InputPort(k).DirectFeedthrough=true; end
block.OutputPort(1).Dimensions=4; block.OutputPort(2).Dimensions=62;
block.SampleTimes=[.02 0]; block.SimStateCompliance='DefaultSimState';
block.RegBlockMethod('Start',@start); block.RegBlockMethod('Outputs',@outputs);
block.RegBlockMethod('Terminate',@terminate);
end
function start(b)
cfg=b.DialogPrm(1).Data; if b.NumDialogPrms==2, cfg.controller_id=b.DialogPrm(2).Data; end
names=controller_registry; cfg.controller_name=names{cfg.controller_id};
ems_runtime('reset',b.BlockHandle,cfg);
end
function outputs(b)
wrapperTimer=tic;
[u,d]=ems_runtime('step',b.BlockHandle,b.CurrentTime,b.InputPort(1).Data,b.InputPort(2).Data,b.InputPort(3).Data);
b.OutputPort(1).Data=double(u(:)); b.OutputPort(2).Data=double(d(:));
ems_runtime('record_wrapper',b.BlockHandle,b.CurrentTime,toc(wrapperTimer));
end
function terminate(b)
ems_runtime('remove',b.BlockHandle);
end
