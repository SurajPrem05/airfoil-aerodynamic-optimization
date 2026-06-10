function best_pareto_set = runGA(CFG)

    N = CFG.N_CST;
    nvars = 2*N + 1;

    % Prevent leading-edge pinch and criss-crossing
    lb_Au = 0.05 * ones(1, N); 
    lb_Au(1) = 0.15; 
    ub_Au = 0.40 * ones(1, N);

    lb_Al = -0.40 * ones(1, N);
    ub_Al = -0.05 * ones(1, N);
    ub_Al(1) = -0.15; 

    lb_dz = 0.002; 
    ub_dz = 0.010; 

    lb = [lb_Au, lb_Al, lb_dz];
    ub = [ub_Au, ub_Al, ub_dz];

    % Multi-Objective options
    options = optimoptions('gamultiobj', ...
        'PopulationSize', CFG.PopulationSize, ...
        'MaxGenerations', CFG.MaxGenerations, ...
        'Display', 'iter', ...
        'PlotFcn', @gaplotpareto, ...
        'UseParallel', true);

    % Point to the multi-objective fitness function
    obj = @(x)multiObjectiveFcn(x,CFG);

    % Run the Multi-Objective Solver
    [best_pareto_set, ~] = gamultiobj(obj, nvars, [], [], [], [], lb, ub, [], options);

end