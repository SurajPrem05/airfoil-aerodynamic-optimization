function CFG = config()

CFG.ProjectName = 'Transonic Airfoil Evolution Platform';

%% Flight Condition

CFG.Mach = 0.65; % CHANGE to preferred settings
CFG.Re   = 5e6;
CFG.Alpha = 2.0;

%% Optimization

CFG.CL_Target = 0.40;

CFG.PopulationSize = 200;
CFG.MaxGenerations = 100;

CFG.N_CST = 8;

%% Geometry

CFG.NumPts = 201;

%% XFOIL

CFG.XfoilExe = fullfile(pwd,'xfoil.exe');

%% Export

CFG.ResultsDir = 'Results';
CFG.AirfoilDir = 'Airfoils';

if ~exist(CFG.ResultsDir,'dir')
    mkdir(CFG.ResultsDir);
end

if ~exist(CFG.AirfoilDir,'dir')
    mkdir(CFG.AirfoilDir);
end

end