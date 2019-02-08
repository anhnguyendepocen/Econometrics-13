## BLP - Main
# Fabrizio Leone
# 07 - 02 - 2019

#------------- Install and Upload Packages -------------#
#import Pkg; Pkg.add("Distributions")
#import Pkg; Pkg.add("LinearAlgebra")
#import Pkg; Pkg.add("Optim")
#import Pkg; Pkg.add("NLSolversBase")
#import Pkg; Pkg.add("Random")
#import Pkg; Pkg.add("Plots")
#import Pkg; Pkg.add("Statistics")
#import Pkg; Pkg.add("DataFrames")
#import Pkg; Pkg.add("CSV")
#import Pkg; Pkg.add("RecursiveArrayTools")

cd("$(homedir())/Documents/GitHub/Econometrics/BLP")

using Distributions, LinearAlgebra, Optim, NLSolversBase, Random, Plots, Statistics, DataFrames, CSV, RecursiveArrayTools
Random.seed!(10);

#------------- Read data and initialize useful objects -------------#
data           = CSV.read("data.csv", header=0, normalizenames=true)
IDmkt          = data[:,1];                                                    # Market identifier
IDprod         = data[:,2];                                                    # Product identifier
share          = data[:,3];                                                    # Market share
A              = Array{Float64,2}(data[:,4:6]);                                # Product characteristics
price          = data[:,7];                                                    # Price
z              = Array{Float64,2}(data[:,8:10]);                               # Instruments
TM             = maximum(IDmkt);                                               # Number of markets
prods          = Array{Int64,1}(zeros(TM));                                    # Number of products in each market
for m=1:TM
    prods[m,1] = maximum(IDprod[IDmkt.==m,1]);
end
T              = Array{Int64,2}(zeros(TM,2));
T[1,1]         = 1;
T[1,2]         = prods[1,1];
for i=2:TM
    T[i,1]     = T[i-1,2]+1;                                                   # 1st Column market starting point
    T[i,2]     = T[i,1]+prods[i,1]-1;                                          # 2nd Column market ending point
end
Total          = trunc(Int64, T[TM,2]);                                        # Number of obsevations
TotalProd      = maximum(prods);                                               # Max # of products in a given market
sharesum_0     = zeros(TM,Total);                                              # Used to create denominators in predicted shares (i.e. sums numerators)
denomexpand_0  = zeros(Total,1);                                               # Used to create denominators in predicted shares (expands sum numerators)
for i=1:TM
    sharesum_0[i,T[i,1]:T[i,2]]    = Array{Int64,2}(ones(1,prods[i]));
    denomexpand_0[T[i,1]:T[i,2],1] = i.*Array{Int64,2}(ones(prods[i],1));
end
sharesum       = Array{Float64,2}(sharesum_0);
denomexpand    = Array{Float64,2}(denomexpand_0);

#------------- Initialize Optimization -------------#
Kbeta          = 2+size(A,2);                                                  #  Number of parameters in mean utility
Ktheta         = 1+size(A,2);                                                  #  Number of parameters with random coefficient
nn             = 200;                                                          #  Draws to simulate shares
v              = rand(Ktheta,nn);                                              #  Draws for share integrals during estimation (we draw a fictious sample of 100 individuals from a normal distribution)
X              = [ones(size(A,1),1) A price];                                  #  Covariates
Z              = [ones(Total,1) A z A.^2 z.^2];                                #  Instruments
nZ             = size(Z,2);                                                    #  Number of instrumental variables
W              = (Z'*Z)\I;                                                     #  Starting GMM weighting matrix
true_vals      = [3, 3, 0.5, 0.5, -2, 0.8, 0.5, 0.5, 0.5]';
x0             = rand(Kbeta+Ktheta,1);                                         #  Random starting values
x_L            = [-Inf*ones(Kbeta,1);zeros(Ktheta,1)];                         #  Lower bounds is zero for standard deviations of random coefficients
x_U            = Inf.*ones(Kbeta+Ktheta,1);                                    #  Upper bounds for standard deviations of random coefficients
function fun(x)
    Obj_function(x[1:9],X,A,price,v,TM,sharesum,Z,W)
end

res  = Optim.optimize(fun,x0)
