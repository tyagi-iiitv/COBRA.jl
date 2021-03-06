#-------------------------------------------------------------------------------------------
#=
    Purpose:    Test selective reactions (serial)
    Author:     Laurent Heirendt - LCSB - Luxembourg
    Date:       October 2016
=#

#-------------------------------------------------------------------------------------------

using Base.Test

if !isdefined(:includeCOBRA) includeCOBRA = true end

# output information
testFile = @__FILE__

# number of workers
nWorkers = 1

# create a pool and use the COBRA module if the testfile is run in a loop
if includeCOBRA
    solverName = :GLPKMathProgInterface
    connectSSHWorkers = false
    include("$(dirname(@__FILE__))/../src/connect.jl")

    # create a parallel pool and determine its size
    if isdefined(:nWorkers) && isdefined(:connectSSHWorkers)
        workersPool, nWorkers = createPool(nWorkers, connectSSHWorkers)
    end

    using COBRA
end

# include a common deck for running tests
include("$(dirname(@__FILE__))/../config/solverCfg.jl")

# change the COBRA solver
solver = changeCobraSolver(solverName, solParams)

# load an external mat file
model = loadModel("$(dirname(@__FILE__))/ecoli_core_model.mat", "S", "model")

# define an optPercentage value
optPercentage = 90.0

# run all the reactions as a reference
minFlux1, maxFlux1, optSol1, fbaSol1, fvamin1, fvamax1, statussolmin1, statussolmax1 = distributedFBA(model, solver, nWorkers, optPercentage, "max")

rxnsList = [1; 18; 10; 20:30; 90; 93; 95]
rxnsOptMode = [0; 1; 2; 2 + zeros(Int, length(20:30)); 2; 1; 0]

# run only a few reactions with rxnsOptMode and rxnsList
minFlux, maxFlux, optSol, fbaSol, fvamin, fvamax, statussolmin, statussolmax = distributedFBA(model, solver, nWorkers, optPercentage, "max", rxnsList, 0, rxnsOptMode)

# test the solution status
@test norm(statussolmin[rxnsList] - [1; -1; 1; ones(Int, length(20:30)); 1; -1; 1]) < 1e-9
@test norm(statussolmax[rxnsList] - [-1; 1; 1; ones(Int, length(20:30)); 1; 1; -1]) < 1e-9

# test fbaSol vectors
@test norm(fbaSol - fbaSol1) < 1e-9
@test abs(optSol - optSol1) < 1e-9

#other solvers (e.g., CPLEX) might report alternate optimal solutions
if solverName == "GLPKMathProgInterface"
    # test minimum flux vectors
    @test norm(fvamin[:, 4:14] - fvamin1[:, 20:30]) < 1e-9

    # text maximum flux vectors
    @test norm(fvamax[:, 4:14] - fvamax1[:, 20:30]) < 1e-9
end

# test rxnsOptMode and rxnsList criteria
@test norm(minFlux[[1; 10; 20:30; 90; 95]] - minFlux1[[1; 10; 20:30; 90; 95]]) < 1e-9
@test norm(maxFlux[[18; 10; 20:30; 90; 93]] - maxFlux1[[18; 10; 20:30; 90; 93]]) < 1e-9

# run only the reactions of the rxnsList (both maximizations and minimizations)
startTime   = time()
minFlux, maxFlux, optSol, fbaSol, fvamin, fvamax, statussolmin, statussolmax = distributedFBA(model, solver, nWorkers, optPercentage, "max", rxnsList)
solTime = time() - startTime

@test norm(minFlux1[rxnsList] - minFlux[rxnsList]) < 1e-9
@test norm(maxFlux1[rxnsList] - maxFlux[rxnsList]) < 1e-9
@test norm(optSol1 - optSol) < 1e-9
@test norm(fbaSol1 - fbaSol) < 1e-9

#other solvers (e.g., CPLEX) might report alternate optimal solutions
if solverName == "GLPKMathProgInterface"
    # test minimum flux vectors
    @test norm(fvamin[:, 4:14] - fvamin1[:, 20:30]) < 1e-9

    # text maximum flux vectors
    @test norm(fvamax[:, 4:14] - fvamax1[:, 20:30]) < 1e-9
end

# save the variables to the current directory
saveDistributedFBA("testFile.mat")

# remove the file to clean up
run(`rm testFile.mat`)

# print a solution summary
printSolSummary(testFile, optSol, maxFlux, minFlux, solTime, nWorkers, solverName)
