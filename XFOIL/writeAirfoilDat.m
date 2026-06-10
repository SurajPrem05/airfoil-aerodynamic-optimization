function writeAirfoilDat(filename,x,yu,yl)

fid = fopen(filename,'w');

fprintf(fid,'MATLAB_CST_AIRFOIL\n');

for i = length(x):-1:1
    fprintf(fid,'%.8f %.8f\n',x(i),yu(i));
end

for i = 2:length(x)
    fprintf(fid,'%.8f %.8f\n',x(i),yl(i));
end

fclose(fid);

end