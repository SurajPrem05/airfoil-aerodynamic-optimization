clc
clear
close all

CFG = config();

fprintf('\n');
fprintf('=========================================\n');
fprintf('%s\n',CFG.ProjectName);
fprintf('=========================================\n');

addpath(genpath(pwd));

%% Baseline Airfoil
N = CFG.N_CST;
Upper0 = [0.20 0.25 0.22 0.18 0.14 0.10 0.08 0.05];
Lower0 = [-0.18 -0.22 -0.18 -0.14 -0.10 -0.08 -0.05 -0.03];

% Applied a finite trailing edge thickness (dz = 0.002) 
% to prepare the geometry for Fluent meshing later.
[x,yu,yl] = cstAirfoil(Upper0,Lower0,0.002,CFG.NumPts);

%% Export Airfoil
datfile = fullfile(CFG.AirfoilDir,'baseline.dat');
writeAirfoilDat(datfile,x,yu,yl);

%% XFOIL Analysis (Baseline)
[CL_base,CD_base] = runXfoil(datfile, CFG.Alpha, CFG.Re, CFG.Mach, CFG);
fprintf('\n--- Baseline Performance ---\n');
fprintf('CL = %.4f\n', CL_base);
fprintf('CD = %.5f\n', CD_base);

%% OPTIMIZATION

best_pareto_set = runGA(CFG);
disp('Multi-Objective Optimization complete!');

%% Post-Processing & Best Selection
% The GA returned an entire Pareto front of shapes. 
% We will locate the single most aerodynamically efficient shape (Highest L/D)
% to export as our ANSYS validation.

N = CFG.N_CST;
num_solutions = size(best_pareto_set, 1);
best_LD = -Inf;
best_index = 1;

fprintf('\nScanning %d Pareto-optimal shapes to find highest L/D ratio\n', num_solutions);

% Test all Pareto designs to find the best aerodynamic efficiency
for i = 1:num_solutions
    vars = best_pareto_set(i, :);
    [x_tmp, yu_tmp, yl_tmp] = cstAirfoil(vars(1:N), vars(N+1:2*N), vars(end), CFG.NumPts);
    
    uniqueID = num2str(randi([1000000, 9999999]));
    tmpFile = sprintf('eval_%s.dat', uniqueID);
    writeAirfoilDat(tmpFile, x_tmp, yu_tmp, yl_tmp);
    
    [CL_tmp, CD_tmp, ~, ~] = runXfoil(tmpFile, CFG.Alpha, CFG.Re, CFG.Mach, CFG);
    
    if exist(tmpFile, 'file'), delete(tmpFile); end
    
    if ~isnan(CL_tmp) && ~isnan(CD_tmp)
        current_LD = CL_tmp / CD_tmp;
        if current_LD > best_LD
            best_LD = current_LD;
            best_index = i;
        end
    end
end

% Extract the Best Airfoil Geometry
best_vars = best_pareto_set(best_index, :);
Au_opt = best_vars(1:N);
Al_opt = best_vars(N+1:2*N);
dz_opt = best_vars(end);

% Generate Best Airfoil Geometry
[x_opt, yu_opt, yl_opt] = cstAirfoil(Au_opt, Al_opt, dz_opt, CFG.NumPts);

% Plot Best Airfoil over Baseline
plot(x_opt, yu_opt, 'r-', 'LineWidth', 2, 'DisplayName', 'Highest L/D Pareto Airfoil')
plot(x_opt, yl_opt, 'r-', 'LineWidth', 2, 'HandleVisibility', 'off')

% Export the Best Airfoil for ANSYS Fluent
bestFile = fullfile(CFG.AirfoilDir, 'bestAirfoil.dat');
writeAirfoilDat(bestFile, x_opt, yu_opt, yl_opt);
fprintf('\nBest airfoil exported to: %s\n', bestFile);

% Run final verification on Best Airfoil
[CL_opt, CD_opt, CM_opt, Xtr_opt] = runXfoil(bestFile, CFG.Alpha, CFG.Re, CFG.Mach, CFG);
fprintf('\n--- Highest L/D Best Performance ---\n');
fprintf('CL = %.4f (Soft Floor: 0.35)\n', CL_opt);
fprintf('CD = %.5f\n', CD_opt);
fprintf('L/D Ratio = %.2f\n', CL_opt/CD_opt);
fprintf('Pitching Moment (Cm) = %.4f\n', CM_opt);
fprintf('Laminar Top Extent = %.1f%%\n', Xtr_opt * 100);