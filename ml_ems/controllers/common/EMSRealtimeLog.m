classdef EMSRealtimeLog < handle
 % Fixed-capacity online buffers. Rich events are reconstructed offline.
 properties
  capacity;decisionCapacity;counts;wrapper_times;diagnostics;projection_times;
  execution_commands;execution_plan;module_times;forecasts;safety_inputs;
 end
 methods
  function obj=EMSRealtimeLog(cfg)
   obj.capacity=ceil(cfg.stop_time/cfg.control.legacy_Ts)+16;
   obj.decisionCapacity=ceil(cfg.stop_time/cfg.control.Ts)+16;
   obj.counts=zeros(1,7);
   obj.wrapper_times=zeros(obj.capacity,2);obj.diagnostics=zeros(obj.capacity,5);
   obj.projection_times=zeros(obj.capacity,3);obj.execution_commands=zeros(obj.capacity,14);
   obj.safety_inputs=zeros(obj.capacity,58);obj.execution_plan=zeros(obj.decisionCapacity,5);
   obj.module_times=zeros(obj.decisionCapacity,4);obj.forecasts=cell(obj.decisionCapacity,1);
  end
  function append(obj,kind,row,varargin)
   k=obj.counts(kind)+1;
   if kind<=5,assert(k<=obj.capacity,'EMS:BufferCapacity','Online callback buffer exhausted.');
   else,assert(k<=obj.decisionCapacity,'EMS:BufferCapacity','Online decision buffer exhausted.');end
   obj.counts(kind)=k;
   switch kind
    case 1,obj.wrapper_times(k,:)=row;
    case 2,obj.diagnostics(k,:)=row;
    case 3,obj.projection_times(k,:)=row;
    case 4,obj.execution_commands(k,:)=row;
    case 5,obj.safety_inputs(k,:)=row;
    case 6,obj.execution_plan(k,:)=row;
    case 7,obj.module_times(k,:)=row;obj.forecasts{k}=varargin{1};
   end
  end
  function finishWrapper(obj,elapsed)
   obj.wrapper_times(obj.counts(1),2)=elapsed;
  end
  function r=export(obj,r)
   r.wrapper_times=obj.wrapper_times(1:obj.counts(1),:);
   r.diagnostics=obj.diagnostics(1:obj.counts(2),:);
   r.projection_times=obj.projection_times(1:obj.counts(3),:);
   r.execution_commands=obj.execution_commands(1:obj.counts(4),:);
   r.safety_inputs=obj.safety_inputs(1:obj.counts(5),:);
   r.execution_plan=obj.execution_plan(1:obj.counts(6),:);
   r.module_times=obj.module_times(1:obj.counts(7),:);
   r.forecasts=obj.forecasts(1:obj.counts(7));
   r=rmfield(r,'storage');
   [present,loc]=ismember(r.wrapper_times(:,1),r.diagnostics(:,1));
   assert(all(present),'EMS:TimingAlignment','Unmatched real wrapper callback.');
   decision=r.diagnostics(loc,2)>0;
   r.max_decision_wrapper_s=max([0;r.wrapper_times(decision,2)]);
   r.max_safety_wrapper_s=max([0;r.wrapper_times(~decision,2)]);
   r.log_schema='fixed-buffer-v1; all callbacks retained; rich events offline';
  end
 end
end
