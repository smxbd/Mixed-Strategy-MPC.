function p = init_vehicle_params()
p=struct(); p.mass=45000; p.frontal_area=7.3; p.drag_coefficient=0.6; p.rolling_coefficient=0.045; p.wheel_radius=0.318;
p.engine=struct('speed_min',1600,'speed_max',4200,'power_max',1103,'speed_idle',3000,'ne_map',[1600 1800 2000 2400 2800 3200 3600 4000 4200],'Te_max_map',[1168 1495 1822 2235 2658 2743 2740 2613 2508]);
p.motor=struct('speed_min',-6000,'speed_max',6000,'torque_max',1110); p.battery=struct('capacity_Ah',70,'soc0',60,'voltage0',900,'power_min',-45,'power_max',45); p.transmission=struct('k1',2.13,'k2',2.13,'k3',2.33,'k4',1.92,'final_drive',4.42);
end
