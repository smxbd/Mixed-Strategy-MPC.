function bus=create_ems_bus
names={'legacy','observation','original_action'}; dims=[19 20 4];
for k=1:3
 e(k)=Simulink.BusElement; e(k).Name=names{k}; e(k).Dimensions=dims(k); e(k).DataType='double';
end
bus=Simulink.Bus; bus.Elements=e;
end
