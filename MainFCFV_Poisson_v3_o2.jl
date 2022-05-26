import UnicodePlots
using Printf, LoopVectorization, LinearAlgebra, SparseArrays

include("CreateMeshFCFV.jl")
include("VisuFCFV.jl")
include("DiscretisationFCFV.jl")
include("DiscretisationFCFV_Poisson_o2.jl")
include("SolversFCFV_Poisson.jl")

#--------------------------------------------------------------------#

function SetUpProblem!( mesh, T, Tdir, Tneu, se, a, b, c, d, alp, bet )
    # Evaluate T analytic on cell faces
    @avx for in=1:mesh.nf
        x        = mesh.xf[in]
        y        = mesh.yf[in]
        Tdir[in] = exp(alp*sin(a*x + c*y) + bet*cos(b*x + d*y))
        dTdx     = Tdir[in] * (a*alp*cos(a*x + c*y) - b*bet*sin(b*x + d*y))
        dTdy     = Tdir[in] * (alp*c*cos(a*x + c*y) - bet*d*sin(b*x + d*y))
        Tneu[in] = -dTdy # nx*dTdx + nt*dTdy on SOUTH face
    end
    # Evaluate T analytic on barycentres
    @avx for iel=1:mesh.nel
        x       = mesh.xc[iel]
        y       = mesh.yc[iel]
        T       = exp(alp*sin(a*x + c*y) + bet*cos(b*x + d*y))
        T[iel]  = T
        se[iel] = T*(-a*alp*cos(a*x + c*y) + b*bet*sin(b*x + d*y))*(a*alp*cos(a*x + c*y) - b*bet*sin(b*x + d*y)) + T*(a^2*alp*sin(a*x + c*y) + b^2*bet*cos(b*x + d*y)) + T*(-alp*c*cos(a*x + c*y) + bet*d*sin(b*x + d*y))*(alp*c*cos(a*x + c*y) - bet*d*sin(b*x + d*y)) + T*(alp*c^2*sin(a*x + c*y) + bet*d^2*cos(b*x + d*y))
    end
    return
end

#--------------------------------------------------------------------#

function ComputeError( mesh, Te, qx, qy, a, b, c, d, alp, bet )
    eT  = zeros(mesh.nel)
    eqx = zeros(mesh.nel)
    eqy = zeros(mesh.nel)
    Ta  = zeros(mesh.nel)
    qxa = zeros(mesh.nel)
    qya = zeros(mesh.nel)
    @avx for iel=1:mesh.nel
        x        = mesh.xc[iel]
        y        = mesh.yc[iel]
        Ta[iel]  = exp(alp*sin(a*x + c*y) + bet*cos(b*x + d*y))
        qxa[iel] = -Ta[iel] * (a*alp*cos(a*x + c*y) - b*bet*sin(b*x + d*y))
        qya[iel] = -Ta[iel] * (alp*c*cos(a*x + c*y) - bet*d*sin(b*x + d*y))
        eT[iel]  = Te[iel] - Ta[iel]
        eqx[iel] = qx[iel] - qxa[iel]
        eqy[iel] = qy[iel] - qya[iel]
    end
    errT  = norm(eT)/norm(Ta)
    errqx = norm(eqx)/norm(qxa)
    errqy = norm(eqy)/norm(qya)
    return errT, errqx, errqy
end
    
#--------------------------------------------------------------------#

function StabParam(tau, dA, Vol, mesh_type)
    if mesh_type=="Quadrangles";        taui = tau;    end
    # if mesh_type=="UnstructTriangles";  taui = tau*dA; end
    if mesh_type=="UnstructTriangles";  taui = tau end
    return taui
end

#--------------------------------------------------------------------#
    
@views function main( n )

    println("\n******** FCFV POISSON ********")

    # Create sides of mesh
    xmin, xmax = 0, 1
    ymin, ymax = 0, 1
    nx, ny     = n*8, n*8
    R          = 0.5
    inclusion  = 0
    solver     = 1
    o2         = 1
    BC         = [1; 1; 1; 1] # S E N W --- 1: Dirichlet / 2: Neumann
    # mesh_type  = "Quadrangles"
    mesh_type  = "UnstructTriangles"
  
    # Generate mesh
    if mesh_type=="Quadrangles" 
        if o2==0 tau  = 1e0 end
        if o2==1 tau  = 1e4 end
        mesh = MakeQuadMesh( nx, ny, xmin, xmax, ymin, ymax, inclusion, R, BC )
    elseif mesh_type=="UnstructTriangles"  
        if o2==0 tau  = 1e2 end
        if o2==1 tau  = 1e6 end
        mesh = MakeTriangleMesh( nx, ny, xmin, xmax, ymin, ymax, inclusion, R, BC ) 
    end
    println("Number of elements: ", mesh.nel)

    # Source term and BCs etc...
    Tanal  = zeros(mesh.nel)
    se     = zeros(mesh.nel)
    Tdir   = zeros(mesh.nf)
    Tneu   = zeros(mesh.nf)
    alp = 0.1; bet = 0.3; a = 5.1; b = 4.3; c = -6.2; d = 3.4;
    println("Model configuration :")
    @time SetUpProblem!(mesh , Tanal, Tdir, Tneu, se, a, b, c, d, alp, bet)

    # Compute some mesh vectors 
    println("Compute FCFV vectors:")
    @time ae, be, be_o2, ze, pe, mei, pe, rj  = ComputeFCFV_o2(mesh, se, Tdir, tau, o2)

    # Assemble element matrices and RHS
    println("Compute element matrices:")
    @time Kv, fv = ElementAssemblyLoop_o2(mesh, ae, be, be_o2, ze, mei, pe, rj, Tdir, Tneu, tau, o2)

    # Assemble triplets and sparse
    println("Assemble triplets and sparse:")
    @time K, f = CreateTripletsSparse(mesh, Kv, fv)
    
    # Solve
    println("Solve:")
    @time Th = SolvePoisson(mesh, K, f, solver)

    # Reconstruct element values
    println("Compute element values:")
    @time Te, qx, qy = ComputeElementValues_o2(mesh, Th, ae, be, be_o2, ze, rj, mei, Tdir, tau, o2)

    # Compute discretisation errors
    err_T, err_qx, err_qy = ComputeError( mesh, Te, qx, qy, a, b, c, d, alp, bet )
    println("Error in T:  ", err_T )
    println("Error in qx: ", err_qx)
    println("Error in qy: ", err_qy)

    # Visualise
    println("Visualisation:")
    @time PlotMakie( mesh, Te, xmin, xmax, ymin, ymax, :viridis )

end

n = 4
main( n )
# main( n )
# main( n )