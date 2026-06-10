function [CL, CD, CM, Top_Xtr] = runXfoil(datfile, alpha, Re, Mach, CFG)

    CL = NaN; CD = NaN; CM = NaN; Top_Xtr = NaN;

    % Generate unique IDs for thread safety
    uniqueID = num2str(randi([1000000, 9999999]));
    
    % RELATIVE PATHS ONLY! Fortran will crash if paths are too long.
    inpFile = sprintf('xfoil_inp_%s.in', uniqueID);
    polarFile = sprintf('polar_%s.txt', uniqueID);

    fid = fopen(inpFile,'w');
    if fid == -1
        return; % Failsafe if file creation is blocked
    end

    fprintf(fid,'LOAD %s\n',datfile);
    fprintf(fid,'PANE\n');
    fprintf(fid,'OPER\n');
    fprintf(fid,'VISC %.0f\n',Re);
    fprintf(fid,'MACH %.3f\n',Mach);
    fprintf(fid,'ITER 200\n');
    fprintf(fid,'PACC\n');
    fprintf(fid,'%s\n\n',polarFile);
    fprintf(fid,'ALFA %.2f\n',alpha);
    fprintf(fid,'PACC\n\n');
    fprintf(fid,'QUIT\n');
    fclose(fid);

    % Run XFOIL quietly
    cmd = sprintf('"%s" < "%s" > NUL', CFG.XfoilExe, inpFile);
    system(cmd);

    % Parse the results (Extracting CL, CD, CM, and Top_Xtr)
    if exist(polarFile,'file')
        try
            data = readmatrix(polarFile,'FileType','text');
            if size(data,1) >= 1
                CL = data(end,2);
                CD = data(end,3);
                CM = data(end,5);       % Column 5 is Pitching Moment
                Top_Xtr = data(end,6);  % Column 6 is Top Surface Laminar Transition
            end
        catch
            % If readmatrix fails, NaN is preserved
        end
        delete(polarFile);
    end

    % Cleanup input file
    if exist(inpFile,'file')
        delete(inpFile);
    end

end