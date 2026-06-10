# Automated Airfoil Optimization Pipeline

## Overview
Aerodynamic design is no longer driven by manual CAD iteration; it is driven by automated computational optimization. 

This project demonstrates a complete, closed-loop aerodynamic toolchain built from scratch. It mathematically evolves airfoil geometries to find the absolute maximum aerodynamic efficiency.

The pipeline consists of three primary phases:
1.  **Geometry Generation:** Airfoils are constructed using a 17-variable Class Shape Transformation (CST) mathematical parameterization, ensuring all generated shapes are smooth and viable airfoils (including a forced blunt trailing edge for meshing later in CFD).
2.  **Multi-Objective Optimization (MATLAB + XFOIL):** A Genetic Algorithm (`gamultiobj`) evaluates thousands of geometries using XFOIL as a rapid 2D physics solver. The algorithm maps the Pareto frontier by simultaneously maximizing the Lift-to-Drag ratio and the extent of Laminar Flow, while utilizing soft-penalty constraints to maintain a strict Lift Coefficient floor and stable Pitching Moment at Mach 0.8.
3.  **High-Fidelity Validation (ANSYS Fluent):** Because low-fidelity panel methods cannot predict compressible wave drag or shockwave-induced separation, the most optimal geometry can be exported to ANSYS Fluent. Then, a density-based Navier-Stokes simulation utilizing the k-omega SST turbulence model can be run to validate the algorithmic design and visualize the transonic shockwave phenomena.

---

## 1. Required Software
Your system must have the following software installed:

* **MATLAB (R2023a or newer recommended)**
    * Add-on: **Global Optimization Toolbox** (Required for the `gamultiobj` solver).
    * Add-on: **Parallel Computing Toolbox** (Highly recommended to reduce computation time).
* **XFOIL (v6.99)**
    * The `xfoil.exe` executable must be placed directly in the root directory of this project.
* **ANSYS Student / Workbench (2023 or newer)**
    * Requires SpaceClaim, ANSYS Meshing, and Fluent.

---

## 2. Running the MATLAB Optimization

1.  Open `config.m` and set your target flight conditions (e.g., `CFG.Mach = 0.80`, `CFG.CL_Target = 0.40`).
2.  In `config.m`, set your computational limits. For a quick validation test, use `PopulationSize = 50` and `MaxGenerations = 20`. For a production run, use `200` and `100`.
3.  Open `main.m` and click **Run**.
4.  The algorithm will launch a Pareto Front plot. As generations pass, the data points will migrate toward the bottom left as the code mathematically minimizes drag and negative lift.
5.  Upon completion, the code automatically scans the Pareto front and identifies the single shape with the highest L/D ratio. This can then be exported to Ansys for evaluation.

---

## 4. High-Fidelity Validation (ANSYS Fluent)

XFOIL is a 2D panel method and cannot accurately predict transonic wave drag. The exported geometry must be validated using density-based Navier-Stokes CFD.

### Phase A: Geometry (SpaceClaim)

1. **Import the Curve:** Click on the XY plane, go to Insert -> File, and bring the `champion_3D.txt` curve into SpaceClaim. **IMPORTANT: MAKE SURE YOU CLICK ON THE XY PLANE FIRST, OR THIS WILL NOT WORK.**
2. Using the fill tool, click on the airfoil curve to close the shape.
3. **Create the Domain:** Select the Rectangle tool and draw a massive bounding box around the airfoil (20 to 30 meters away to prevent blockage effects). Press D (3D Mode) to convert the box into a solid surface. The airfoil should look very small in the rectangle.
4. **The Boolean Cut:** Click the Combine tool in the Design tab. Click the giant rectangular domain first (Target). In the Structure tree on the left, click the other Surface representing the airfoil curve (Cutter). Press Escape to drop the tool.
5. **Clean the Tree:** Right-click and delete the original solid airfoil surface, and delete the tiny cutout piece left inside the hole. Your Structure tree must have exactly one Surface: a giant sheet of air with an empty hole in the middle. Close SpaceClaim.

### Phase B: Meshing

1. **Check Edge Count:** Because the algorithm forces a blunt trailing edge, your airfoil hole consists of at least 3 edges (top, bottom, and the flat vertical trailing edge).
2. **Create Named Selections:** Zoom in, hold Ctrl, and select all edges making up the airfoil hole. Right-click -> Create Named Selection -> name it `wall-airfoil`. Create selections for the outer bounds: `inlet` (left), `outlet` (right), and `farfield` (top/bottom).
3. **Edge Sizing:** Right-click Mesh -> Insert -> Sizing. Select all edges of the airfoil hole (ensure the scope says 3 Edges, not 1 Edge). Set the element size to `2.e-003 m`.
4. **Inflation Layers (The Boundary Layer):**
    * Right-click Mesh -> Insert -> Inflation.
    * **Geometry:** Click the giant face of the air domain.
    * **Boundary Scoping Method:** Change to Named Selection. Select `wall-airfoil` from the drop-down.
    * Set Maximum Layers to `20` and Growth Rate to `1.2`.
5. Click **Generate Mesh**. Ensure a tight band of 20 elements wraps completely around the hollow wing shape.

### Phase C: Solver Setup & Execution (Fluent)

Double-click Setup. Select Double Precision and set Solver Processes to match your CPU cores.

* **General:** Change Solver Type to Density-Based (Mandatory for shockwaves).
* **Models:** Turn Energy ON. Set Viscous to k-omega SST.
* **Materials:** Change Air Density to Ideal Gas.
* **Boundary Conditions:** Change `inlet` to Pressure Far-Field at Mach 0.80.
* **Initialization & Run:** Standard Initialization (compute from inlet). Set Iterations to `1000` and hit Calculate.

### Phase D: Post-Processing & Physics Interpretation

To visualize why the genetic algorithm made its design choices, generate a Mach contour plot:

1. Navigate to Results -> Graphics -> Contours.
2. Ensure Filled is checked. Select Velocity... and Mach Number. 
3. Leave Surfaces blank to color the entire flow field, then click Save/Display.

### Interpreting the Results (The "XFOIL Lie")

During optimization, XFOIL may report an impossibly high Lift-to-Drag ratio (e.g., L/D > 170). Because XFOIL is a 2D panel method, it is fundamentally blind to supersonic flow and cannot calculate Wave Drag. The algorithm exploits this by optimizing purely for skin-friction reduction, evolving a geometry that maximizes laminar flow.

However, the ANSYS Navier-Stokes validation reveals the true physics. In the Mach contour plot, you will observe:

* **Supersonic Flow:** The air accelerating over the top surface exceeds Mach 1.0 (deep red zones).
* **Transonic Shockwaves:** A harsh, vertical color gradient where the flow violently decelerates back to subsonic speeds.
* **Boundary Layer Separation:** The shockwave triggers flow separation at the blunt trailing edge, resulting in a turbulent wake.

This pipeline physically demonstrates the critical gap between rapid low-fidelity screening and high-fidelity aerodynamic validation: an algorithm will perfectly solve the math you give it, but only Navier-Stokes CFD will enforce the laws of physics.

## 3. Preparing the Geometry for ANSYS
ANSYS SpaceClaim strictly requires coordinate curves to be in a comma-delimited 3D format (X, Y, Z) with explicit software headers. To automatically convert the XFOIL `.dat` output into a SpaceClaim-ready file, run this script in your MATLAB command window:

```matlab
% 1. Read data
data = readmatrix('Airfoils/champion.dat');
x = data(:,1);
y = data(:,2);
z = zeros(length(x), 1); % Add Z=0 column for 3D import

% 2. Write in SpaceClaim format
fid = fopen('Airfoils/champion_3D.txt', 'w');
fprintf(fid, '3d=true\n');
fprintf(fid, 'polyline=false\n');

for i = 1:length(x)
    % Commas are strictly required by SpaceClaim
    fprintf(fid, '%.8f, %.8f, %.8f\n', x(i), y(i), z(i)); 
end
fclose(fid);
```
---

## 4. High-Fidelity Validation (ANSYS Fluent)

XFOIL is a 2D panel method and cannot accurately predict transonic wave drag. The exported geometry must be validated using density-based Navier-Stokes CFD.

### Phase A: Geometry (SpaceClaim)

1. **Import the Curve:** Click on the XY plane, go to Insert -> File, and bring the `champion_3D.txt` curve into SpaceClaim. **IMPORTANT: MAKE SURE YOU CLICK ON THE XY PLANE FIRST, OR THIS WILL NOT WORK.**
2. Using the fill tool, click on the airfoil curve to close the shape.
3. **Create the Domain:** Select the Rectangle tool and draw a massive bounding box around the airfoil (20 to 30 meters away to prevent blockage effects). Press D (3D Mode) to convert the box into a solid surface. The airfoil should look very small in the rectangle.
4. **The Boolean Cut:** Click the Combine tool in the Design tab. Click the giant rectangular domain first (Target). In the Structure tree on the left, click the other Surface representing the airfoil curve (Cutter). Press Escape to drop the tool.
5. **Clean the Tree:** Right-click and delete the original solid airfoil surface, and delete the tiny cutout piece left inside the hole. Your Structure tree must have exactly one Surface: a giant sheet of air with an empty hole in the middle. Close SpaceClaim.

### Phase B: Meshing

1. **Check Edge Count:** Because the algorithm forces a blunt trailing edge, your airfoil hole consists of at least 2 edges.
2. **Create Named Selections:** Zoom in, hold Ctrl, and select all edges making up the airfoil hole. Right-click -> Create Named Selection -> name it `wall-airfoil`. Create selections for the outer bounds of the rectangle: `inlet` (left), `outlet` (right), and `farfield` (top/bottom).
3. **Edge Sizing:** Right-click Mesh -> Insert -> Sizing. Select all edges of the airfoil hole (ensure the scope says 2 Edges, not 1 Edge). Set the element size to `2.e-003 m`.
4. **Inflation Layers (The Boundary Layer):**
    * Right-click Mesh -> Insert -> Inflation.
    * **Geometry:** Click the giant face of the air domain.
    * **Boundary Scoping Method:** Change to Named Selection. Select `wall-airfoil` from the drop-down.
    * Set Maximum Layers to `20` and Growth Rate to `1.2`.
5. Click **Generate Mesh**. Ensure a tight band of 20 elements wraps completely around the hollow wing shape.

### Phase C: Solver Setup & Execution (Fluent)

Double-click Setup. Select Double Precision and set Solver Processes to match your CPU cores.

* **General:** Change Solver Type to Density-Based (Mandatory for shockwaves).
* **Models:** Turn Energy ON. Set Viscous to k-omega SST.
* **Materials:** Change Air Density to Ideal Gas.
* **Boundary Conditions:** Change `inlet` to Pressure Far-Field at Mach 0.80.
* **Initialization & Run:** Standard Initialization (compute from inlet). Set Iterations to `1000` and hit Calculate.

### Phase D: Post-Processing & Physics Interpretation

To visualize why the genetic algorithm made its design choices, generate a Mach contour plot:

1. Navigate to Results -> Graphics -> Contours.
2. Ensure Filled is checked. Select Velocity... and Mach Number. 
3. Leave Surfaces blank to color the entire flow field, then click Save/Display.

### Interpreting the Results (The "XFOIL Lie")

During optimization, XFOIL may report an impossibly high Lift-to-Drag ratio (e.g., L/D > 170). Because XFOIL is a 2D panel method, it is fundamentally blind to supersonic flow and cannot calculate Wave Drag. The algorithm exploits this by optimizing purely for skin-friction reduction, evolving a geometry that maximizes laminar flow.

However, the ANSYS validation reveals:

* **Supersonic Flow:** The air accelerating over the top surface exceeds Mach 1.0 (deep red zones).
* **Transonic Shockwaves:** A harsh, vertical color gradient where the flow violently decelerates back to subsonic speeds.
* **Boundary Layer Separation:** The shockwave triggers flow separation at the blunt trailing edge, resulting in a turbulent wake.
