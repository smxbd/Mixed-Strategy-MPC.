function rebuild_recovery_svg(project_root)
% Headless, dependency-free SVG export from saved trajectory arrays.
root=fullfile(project_root,'ml_ems','results'); out=fullfile(project_root,'recovery_figures'); if ~isfolder(out), mkdir(out); end
spec={
 'city200','Existing','city200_m1_s20261012_20261011_004813_0d4e0b29'; 'city200','LSTM','city200_m6_s20261014_20261011_133336_74413f17'; 'city200','Transformer','city200_m7_s20261014_20261011_131850_5160b2a4';
 'suburban400','Existing','suburban400_m1_s20261012_20261011_005425_b8bd05d2'; 'suburban400','LSTM','suburban400_m6_s20261014_20261011_133803_166f7c01'; 'suburban400','Transformer','suburban400_m7_s20261014_20261011_132257_16010f90';
 'stress300','Existing','stress300_m1_s20261012_20261011_005728_6da2800b'; 'stress300','LSTM','stress300_m6_s20261014_20261011_134112_44108796'; 'stress300','Transformer','stress300_m7_s20261014_20261011_132606_a2453274'};
 for ci=1:3
  f=fopen(fullfile(out,[spec{(ci-1)*3+1,1} '_tracking.svg']),'w'); fprintf(f,'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="700" viewBox="0 0 1000 700">\n');
  for ri=1:3
   k=(ci-1)*3+ri; s=load(fullfile(root,spec{k,3},'run.mat'),'run'); r=s.run; t=r.time(:); o=r.trace(:,20:39); n=min(1000,numel(t)); ix=round(linspace(1,numel(t),n)); tt=t(ix); ref=o(ix,1); act=o(ix,2); x0=80; y0=80+(ri-1)*200; w=850; h=150; xmin=min(tt); xmax=max(tt); ymin=min([ref;act]); ymax=max([ref;act]);
   fprintf(f,'<text x="%g" y="%g" font-size="18">%s</text>\n',x0,y0-25,spec{k,2});
   fprintf(f,'<rect x="%g" y="%g" width="%g" height="%g" fill="white" stroke="black"/>\n',x0,y0,w,h);
   write_polyline(f,tt,ref,x0,y0,w,h,xmin,xmax,ymin,ymax,'#222222'); write_polyline(f,tt,act,x0,y0,w,h,xmin,xmax,ymin,ymax,'#1565c0');
  end
  fprintf(f,'<text x="80" y="690" font-size="16">black=reference, blue=actual; time (s)</text></svg>\n'); fclose(f);
 end
end
function write_polyline(f,t,y,x0,y0,w,h,xmin,xmax,ymin,ymax,color)
 fprintf(f,'<polyline fill="none" stroke="%s" points="',color);
 for i=1:numel(t), x=x0+w*(t(i)-xmin)/max(xmax-xmin,eps); yy=y0+h*(1-(y(i)-ymin)/max(ymax-ymin,eps)); fprintf(f,'%.2f,%.2f ',x,yy); end
 fprintf(f,'"/>\n');
end
