function scores = multiObjectiveFcn(vars, CFG)
    % Unpack 17 variables
    N = CFG.N_CST;
    Au = vars(1:N);
    Al = vars(N+1:2*N);
    dz = vars(end);

    % Generate geometry
    [x, yu, yl] = cstAirfoil(Au, Al, dz, CFG.NumPts);

    % Reject self-intersecting shapes
    if any(yl(2:end) >= yu(2:end))
        scores = [1000, 1000]; % Throw out the shape immediately
        return;
    end

    % Write temp dat file for XFOIL
    uniqueID = num2str(randi([1000000, 9999999]));
    datfile = sprintf('temp_%s.dat', uniqueID);
    writeAirfoilDat(datfile, x, yu, yl);

    % Run XFOIL (Now pulling 4 outputs)
    [CL, CD, CM, Top_Xtr] = runXfoil(datfile, CFG.Alpha, CFG.Re, CFG.Mach, CFG);

    % Clean up temporary file
    if exist(datfile, 'file')
        delete(datfile);
    end

    % If XFOIL fails to converge, throw out the shape
    if isnan(CL) || isnan(CD)
        scores = [1000, 1000]; 
        return;
    end

    % OBJECTIVES
    % Objective 1: Maximize Efficiency (L/D) -> We minimize the negative ratio
    Obj1 = -(CL / CD); 

    % Objective 2: Maximize Laminar Flow -> We minimize negative transition point
    Obj2 = -Top_Xtr;

    % RUBBER BAND PENALTIES
    penalty = 0;

    % Constraint 1: Lift Floor (Allow a slight 0.05 drop below target for massive drag savings)
    lift_floor = CFG.CL_Target - 0.05; 
    
    if CL < lift_floor
        penalty = penalty + ((lift_floor - CL) * 10000);
    end

    % Constraint 2: Pitching Moment (Punish if violently unstable)
    % A good transonic wing has a slightly negative Cm (e.g., between 0 and -0.15)
    if CM > 0
        penalty = penalty + (CM * 5000); % Punish pitch-up
    elseif CM < -0.15
        penalty = penalty + (abs(CM + 0.15) * 5000); % Punish extreme pitch-down
    end

    % Apply final penalties to both objectives
    scores = [Obj1 + penalty, Obj2 + penalty];
end