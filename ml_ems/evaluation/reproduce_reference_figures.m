function out = reproduce_reference_figures(projectRoot, outDir)
% Recreate the supplied reference figures from the saved full-duration runs.
% This produces PNG/SVG artifacts; the supplied PDFs remain untouched.
if nargin < 1, projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath')))); end
if nargin < 2, outDir = fullfile(projectRoot,'reproduced_figures'); end
if ~isfolder(outDir), mkdir(outDir); end
R = fullfile(projectRoot,'ml_ems','results');
spec = {
 'city200','Existing','city200_m1_s20261012_20261011_004813_0d4e0b29';
 'city200','LSTM','city200_m6_s20261014_20261011_133336_74413f17';
 'city200','Transformer','city200_m7_s20261014_20261011_131850_5160b2a4';
 'suburban400','Existing','suburban400_m1_s20261012_20261011_005425_b8bd05d2';
 'suburban400','LSTM','suburban400_m6_s20261014_20261011_133803_166f7c01';
 'suburban400','Transformer','suburban400_m7_s20261014_20261011_132257_16010f90';
 'stress300','Existing','stress300_m1_s20261012_20261011_005728_6da2800b';
 'stress300','LSTM','stress300_m6_s20261014_20261011_134112_44108796';
 'stress300','Transformer','stress300_m7_s20261014_20261011_132606_a2453274'};
 runs = cell(size(spec,1),1);
 for k=1:size(spec,1), runs{k}=load(fullfile(R,spec{k,3},'run.mat'),'run').run; end
 colors=[0.000 0.447 0.741; 0.635 0.078 0.184; 0.301 0.745 0.933];
 cycles={'city200','suburban400','stress300'};
 out = struct('directory',outDir,'files',{{}});

 % Three-controller comparison for each cycle.
 for ci=1:3
  ix=(ci-1)*3+(1:3); f=figure('Visible','off','Color','w','Position',[80 80 900 900]);
  tl=tiledlayout(3,1,'TileSpacing','compact');
  for p=1:3
   nexttile; hold on;
   for j=1:3
    r=runs{ix(j)}; y={r.trace(:,21),r.trace(:,22),r.trace(:,39)-r.trace(1,39)}; plot(r.time,y{p},'Color',colors(j,:),'LineWidth',1.0);
   end
   if p==1, r=runs{ix(1)}; plot(r.time,r.trace(:,20),'k:','LineWidth',0.9); ylabel('Vehicle speed (km/h)');
   elseif p==2, ylabel('SOC (%)'); else, ylabel('Cumulative fuel (L)'); xlabel('Simulation time (s)'); end
   grid on; box on;
  end
  title(tl,sprintf('%s: three-controller comparison',cycles{ci}));
  legend({'Existing heuristic-grid EMS','Transformer CEM-MPC','LSTM CEM-MPC','Reference'},'Location','northwest');
  saveFigure(f,fullfile(outDir,[cycles{ci} '_tracking_reproduced'])); close(f);
 end

 % Metrics from the saved run artifacts.
 for ci=1:3
  ix=(ci-1)*3+(1:3); f=figure('Visible','off','Color','w','Position',[80 80 1000 720]);
  tl=tiledlayout(2,2,'TileSpacing','compact'); labels={'Existing heuristic-grid EMS','Transformer CEM-MPC','LSTM CEM-MPC'};
  vals=zeros(3,4); for j=1:3, m=runs{ix(j)}.metrics; vals(j,:)=[m.RMSE_kmh,m.fuel_L,m.delta_SOC_percent,m.equivalent_fuel_L_100km*m.distance_km/100]; end
  titles={'Speed tracking RMSE (km/h)','Cycle fuel consumption (L)','State-of-charge change (pp)','Equivalent fuel (L)'};
  for p=1:4, nexttile; b=bar(vals(:,p),'FaceColor','flat'); b.CData=colors; set(gca,'XTick',1:3,'XTickLabel',labels,'XTickLabelRotation',18); title(titles{p}); grid on; box on; end
  title(tl,sprintf('%s: key performance metrics',cycles{ci}));
  saveFigure(f,fullfile(outDir,[cycles{ci} '_metrics_reproduced'])); close(f);
 end

 % Transformer response, using trace columns documented by ems_runtime and physical observations.
 r=runs{3}; t=r.time(:); q=r.trace; rawPhys=r.physical.signals.values; phys=interp1(r.physical.time(:),rawPhys,t,'linear','extrap'); engSpeed=q(:,5); engTorque=phys(:,17); maSpeed=phys(:,6); mbSpeed=phys(:,7); maTorque=phys(:,18); mbTorque=phys(:,19); battV=phys(:,4); battI=phys(:,5);
 f=figure('Visible','off','Color','w','Position',[80 80 1100 900]); tiledlayout(3,2,'TileSpacing','compact');
 nexttile; plot(t,engSpeed,'Color',[.55 .32 .13]); ylabel('Engine speed (rpm)'); title('a'); grid on;
 nexttile; plot(t,engTorque,'Color',[.30 .34 .40]); ylabel('Engine torque (N m)'); title('b'); grid on;
 nexttile; plot(t,maSpeed,'Color',[.12 .39 .65]); hold on; plot(t,mbSpeed,'Color',[.70 .30 .12]); ylabel('Motor speed (rpm)'); legend('Motor A','Motor B'); title('c'); grid on;
 nexttile; plot(t,maTorque,'Color',[.12 .39 .65]); hold on; plot(t,mbTorque,'Color',[.70 .30 .12]); ylabel('Motor torque (N m)'); legend('Motor A','Motor B'); title('d'); grid on;
 nexttile; plot(t,battV,'Color',[.20 .55 .35]); ylabel('Battery voltage (V)'); xlabel('Simulation time (s)'); title('e'); grid on;
 nexttile; plot(t,battI,'Color',[.35 .30 .55]); ylabel('Battery current (A)'); xlabel('Simulation time (s)'); title('f'); grid on;
 sgtitle('Transformer | powertrain response'); saveFigure(f,fullfile(outDir,'architecture_reproduced')); close(f);

 % Driving/cycle figure.
 f=figure('Visible','off','Color','w','Position',[80 80 1000 850]); tiledlayout(3,2,'TileSpacing','compact'); v=q(:,21); ref=q(:,20); dt=median(diff(t)); accel=[0;diff(v)/3.6/dt]; stage=q(:,4)+1; fuel=q(:,39)-q(1,39);
 nexttile; plot(t,ref,'k:',t,v,'b-'); ylabel('Vehicle speed (km/h)'); legend('Reference','Actual'); grid on;
 nexttile; plot(t,v-ref,'Color',[.65 .30 .16]); ylabel('Tracking error (km/h)'); grid on;
 nexttile; plot(t,accel,'b',t,min(accel,0),'Color',[.65 .30 .16]); ylabel('Accel / brake'); grid on;
 nexttile; stairs(t,stage,'Color',[.45 .40 .60]); ylabel('Stage'); ylim([0.5 4.5]); grid on;
 nexttile; plot(t,q(:,22),'Color',[.20 .55 .35]); ylabel('SOC (%)'); xlabel('Simulation time (s)'); grid on;
 nexttile; plot(t,fuel,'Color',[.55 .32 .13]); ylabel('Cumulative fuel (L)'); xlabel('Simulation time (s)'); grid on;
 sgtitle('Transformer | driving and cycle'); saveFigure(f,fullfile(outDir,'transformer_driving_reproduced')); close(f);

 % Power flow derived from torque-speed and logged battery signals.
 mechA=maSpeed.*maTorque/9549.3/1000; mechB=mbSpeed.*mbTorque/9549.3/1000; engP=max(q(:,32),0); battP=battV.*battI/1000;
 f=figure('Visible','off','Color','w','Position',[80 80 1000 850]); tiledlayout(3,2,'TileSpacing','compact');
 nexttile; plot(t,engP,'Color',[.30 .34 .40]); ylabel('Engine power (kW)'); grid on;
 nexttile; plot(t,battP,'Color',[.20 .55 .35]); ylabel('Battery power (kW)'); grid on;
 nexttile; plot(t,mechA,'Color',[.12 .39 .65]); ylabel('Motor A power (kW)'); grid on;
 nexttile; plot(t,mechB,'Color',[.70 .30 .12]); ylabel('Motor B power (kW)'); grid on;
 nexttile; plot(t,engP+mechA+mechB,'Color',[.35 .30 .55]); ylabel('Combined power (kW)'); xlabel('Simulation time (s)'); grid on;
 nexttile; plot(t,battP+mechA+mechB,'Color',[.30 .40 .50]); ylabel('Electrical balance (kW)'); xlabel('Simulation time (s)'); grid on;
 sgtitle('Transformer | power flow and efficiency'); saveFigure(f,fullfile(outDir,'transformer_powerflow_reproduced')); close(f);

 % Operating-point maps, retaining all points and overlaying simple limit envelopes.
 f=figure('Visible','off','Color','w','Position',[80 80 1000 800]); tiledlayout(2,2,'TileSpacing','compact');
 nexttile; scatter(engSpeed,engTorque,3,t,'filled'); xlabel('Speed (rpm)'); ylabel('Torque (N m)'); title('a Engine points'); grid on; colorbar;
 nexttile; scatter(maSpeed,maTorque,3,t,'filled'); xlabel('Speed (rpm)'); ylabel('Torque (N m)'); title('b Motor A points'); grid on; colorbar;
 nexttile; scatter(mbSpeed,mbTorque,3,t,'filled'); xlabel('Speed (rpm)'); ylabel('Torque (N m)'); title('c Motor B points'); grid on; colorbar;
 nexttile; plot(t,engTorque,'Color',[.65 .30 .16]); xlabel('Simulation time (s)'); ylabel('Torque (N m)'); title('d Torque envelope'); grid on;
 sgtitle('Transformer | operating points and limits'); saveFigure(f,fullfile(outDir,'transformer_maps_reproduced')); close(f);
end

function saveFigure(f,base)
exportgraphics(f,[base '.png'],'Resolution',220);
try, exportgraphics(f,[base '.svg'],'ContentType','vector'); catch, end
end
