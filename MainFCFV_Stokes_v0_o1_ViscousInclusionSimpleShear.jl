import UnicodePlots, Plots
using  Revise, Printf, LoopVectorization, LinearAlgebra, SparseArrays, MAT

include("CreateMeshFCFV.jl")
include("VisuFCFV.jl")
include("DiscretisationFCFV_Stokes.jl")
include("SolversFCFV_Stokes.jl")
include("EvalAnalDani.jl")

#--------------------------------------------------------------------#

function SetUpProblem!(mesh, P, P_f, Vx, Vy, Sxx, Syy, Sxy, VxDir, VyDir, SxxNeu, SyyNeu, SxyNeu, SyxNeu, sx, sy, R, eta, gbar)
    # Evaluate T analytic on cell faces
    etam, etai = eta[1], eta[2]
    for in=1:mesh.nf
        x        = mesh.xf[in]
        y        = mesh.yf[in]
        vx, vy, p, sxx, syy, sxy = EvalAnalDani( x, y, R, etam, etai )
        VxDir[in] = vx
        VyDir[in] = vy
        # Stress at faces - Pseudo-tractions
        p, dVxdx, dVxdy, dVydx, dVydy = Tractions( x, y, R, etam, etai, 1 )
        SxxNeu[in] = - p + etam*dVxdx 
        SyyNeu[in] = - p + etam*dVydy 
        SxyNeu[in] =       etam*dVxdy
        SyxNeu[in] =       etam*dVydx
        P_f[in]    = p
    end
    # Evaluate T analytic on barycentres
    for iel=1:mesh.nel
        x        = mesh.xc[iel]
        y        = mesh.yc[iel]
        vx, vy, pre, sxx, syy, sxy = EvalAnalDani( x, y, R, etam, etai )
        P[iel]   = pre
        Vx[iel]  = vx
        Vy[iel]  = vy
        Sxx[iel] = sxx
        Syy[iel] = syy
        Sxy[iel] = sxy
        sx[iel]  = 0.0
        sy[iel]  = 0.0
        out          = mesh.phase[iel] == 1.0
        mesh.ke[iel] = (out==1) * 1.0*etam + (out!=1) * 1.0*etai
        # Compute jump condition
        for ifac=1:mesh.nf_el
            # Face
            nodei  = mesh.e2f[iel,ifac]
            xF     = mesh.xf[nodei]
            yF     = mesh.yf[nodei]
            nodei  = mesh.e2f[iel,ifac]
            ni_x   = mesh.n_x[iel,ifac]
            ni_y   = mesh.n_y[iel,ifac]
            phase1 = Int64(mesh.phase[iel])
            pre1, dVxdx1, dVxdy1, dVydx1, dVydy1 = Tractions( xF, yF, R, etam, etai, phase1 )
            eta_face1 = eta[phase1]
            tL_x  = ni_x*(-pre1 + eta_face1*dVxdx1) + ni_y*eta_face1*dVxdy1
            tL_y  = ni_y*(-pre1 + eta_face1*dVydy1) + ni_x*eta_face1*dVydx1
            # From element 2
            ineigh = (mesh.e2e[iel,ifac]>0) * mesh.e2e[iel,ifac] + (mesh.e2e[iel,ifac]<1) * iel
            phase2 = Int64(mesh.phase[ineigh])
            pre2, dVxdx2, dVxdy2, dVydx2, dVydy2 = Tractions( xF, yF, R, etam, etai, phase2)
            eta_face2 = eta[phase2]
            tR_x = ni_x*(-pre2 + eta_face2*dVxdx2) + ni_y*eta_face2*dVxdy2
            tR_y = ni_y*(-pre2 + eta_face2*dVydy2) + ni_x*eta_face2*dVydx2
            gbar[iel,ifac,1] = 0.5 * (tL_x - tR_x)
            gbar[iel,ifac,2] = 0.5 * (tL_y - tR_y)
        end          
    end
    return
end

#--------------------------------------------------------------------#

function ComputeError( mesh, Vxe, Vye, Txxe, Tyye, Txye, Pe, R, eta )
    etam, etai = eta[1], eta[2]
    eVx  = zeros(mesh.nel)
    eVy  = zeros(mesh.nel)
    eTxx = zeros(mesh.nel)
    eTyy = zeros(mesh.nel)
    eTxy = zeros(mesh.nel)
    eP   = zeros(mesh.nel)
    Vxa  = zeros(mesh.nel)
    Vya  = zeros(mesh.nel)
    Txxa = zeros(mesh.nel)
    Tyya = zeros(mesh.nel)
    Txya = zeros(mesh.nel)
    Pa   = zeros(mesh.nel)
    Pe_f = zeros(mesh.nf) 
   
    for in=1:mesh.nf

        P_f = 0
        cc  = 0
        if (mesh.f2e[in,1]>0)
            iel  = mesh.f2e[in,1]
            P_f += Pe[iel]
            cc  += 1
        end
        if (mesh.f2e[in,2]>0)
            iel  = mesh.f2e[in,2]
            P_f += Pe[iel]
            cc  += 1
        end
        P_f /= cc
        vx, vy, pre, sxx, syy, sxy = EvalAnalDani( mesh.xf[in], mesh.yf[in], R, etam, etai )
        Pe_f[in] = P_f - pre
    end
    for iel=1:mesh.nel
        x         = mesh.xc[iel]
        y         = mesh.yc[iel]
        vx, vy, pre, sxx, syy, sxy = EvalAnalDani( x, y, R, etam, etai )
        Pa[iel]   = pre
        Vxa[iel]  = vx
        Vya[iel]  = vy
        Txxa[iel] = pre + sxx 
        Tyya[iel] = pre + syy 
        Txya[iel] = sxy
        eVx[iel]  = Vxe[iel]  - Vxa[iel]
        eVy[iel]  = Vye[iel]  - Vya[iel]
        eTxx[iel] = Txxe[iel] - Txxa[iel]
        eTyy[iel] = Tyye[iel] - Tyya[iel]
        eTxy[iel] = Txye[iel] - Txya[iel]
        eP[iel]   = Pe[iel]   - Pa[iel]
    end
    errVx  = norm(eVx) /norm(Vxa)
    errVy  = norm(eVy) /norm(Vya)
    errTxx = norm(eTxx)/norm(Txxa)
    errTyy = norm(eTyy)/norm(Tyya)
    errTxy = norm(eTxy)/norm(Txya)
    errP   = norm(eP)  /norm(Pa)
    return errVx, errVy, errTxx, errTyy, errTxy, errP, Txxa, Tyya, Txya, Pe_f
end

#--------------------------------------------------------------------#
    
function StabParam(τr, Γ, Ω, mesh_type, coeff)
    if mesh_type=="Quadrangles";        τ = τr end#coeff*tau
    if mesh_type=="UnstructTriangles";  τ = τr end#coeff*tau*dA 
    return τ
end

#--------------------------------------------------------------------#

@views function main( n, mesh_type, τr, o2, new )
    # ```This version includes the jump condition derived from the analytical solution
    # The great thing is that pressure converges in L_infinity norm even with quadrangles - this rocks
    # # Test #1: For a contrast of:  eta        = [10.0 1.0] (weak inclusion), tau = 20.0
    #     res = [1 2 4 8]*30 elements per dimension 
    #     err = [4.839 3.944 2.811 1.798]
    # # Test #2: For a contrast of:  eta        = [1.0 100.0] (strong inclusion), tau = 1.0/5.0
    #     res = [1 2 4 8]*30 elements per dimension 
    #     err = [4.169 2.658 1.628 0.83]
    # ```

    println("\n******** FCFV STOKES ********")

    # Create sides of mesh
    xmin, xmax = -3.0, 3.0
    ymin, ymax = -3.0, 3.0
    nx, ny     = 20*n, 20*n
    solver     = 0
    R          = 0.6
    inclusion  = 1
    eta        = [1.0 100.0]
    # mesh_type  = "Quadrangles"
    # mesh_type  = "UnstructTriangles" 
    # mesh_type  = "TrianglesSameMATLAB"
    BC         = [1; 1; 1; 1] # S E N W --- 1: Dirichlet / 2: Neumann
    # new        = 1 # implementation if interface

    # Generate mesh
    if mesh_type=="Quadrangles" 
        tau  = 50.0   # for new = 0 leads to convergence 
        tau  = τr
        mesh = MakeQuadMesh( nx, ny, xmin, xmax, ymin, ymax, τr, inclusion, R, BC )
    elseif mesh_type=="UnstructTriangles" 
        tau = 1.0
        mesh = MakeTriangleMesh( nx, ny, xmin, xmax, ymin, ymax, τr, inclusion, R, BC, ((xmax-xmin)/nx)*((ymax-ymin)/ny), 200 )
    elseif mesh_type=="TrianglesSameMATLAB"  
        tau  = 1.0#/5.0
        area = 1.0 # area factor: SETTING REPRODUCE THE RESULTS OF MATLAB CODE USING TRIANGLE
        ninc = 29  # number of points that mesh the inclusion: SETTING REPRODUCE THE RESULTS OF MATLAB CODE USING TRIANGLE
        mesh = MakeTriangleMesh( nx, ny, xmin, xmax, ymin, ymax, τr, inclusion, R, BC, area, ninc ) 
    end
    println("Number of elements: ", mesh.nel)

    Perr = 0

    # Source term and BCs etc...
    Vxh    = zeros(mesh.nf)
    Vyh    = zeros(mesh.nf)
    Pe     = zeros(mesh.nel)
    Pa     = zeros(mesh.nel)
    Pa_f   = zeros(mesh.nf)
    Vxa    = zeros(mesh.nel)
    Vya    = zeros(mesh.nel)
    Sxxa   = zeros(mesh.nel)
    Syya   = zeros(mesh.nel)
    Sxya   = zeros(mesh.nel)
    sex    = zeros(mesh.nel)
    sey    = zeros(mesh.nel)
    VxDir  = zeros(mesh.nf)
    VyDir  = zeros(mesh.nf)
    SxxNeu = zeros(mesh.nf)
    SyyNeu = zeros(mesh.nf)
    SxyNeu = zeros(mesh.nf)
    SyxNeu = zeros(mesh.nf)
    gbar   = zeros(mesh.nel,mesh.nf_el, 2)
    println("Model configuration :")
    @time SetUpProblem!(mesh, Pa, Pa_f, Vxa, Vya, Sxxa, Syya, Sxya, VxDir, VyDir, SxxNeu, SyyNeu, SxyNeu, SyxNeu, sex, sey, R, eta, gbar)

    mesh.τe .=   mesh.ke
    @show minimum(mesh.τe), maximum(mesh.τe)

    # Compute some mesh vectors 
    println("Compute FCFV vectors:")
    @time ae, be, ze = ComputeFCFV(mesh, sex, sey, VxDir, VyDir, SxxNeu, SyyNeu, SxyNeu, SyxNeu)

    # Assemble element matrices and RHS
    println("Compute element matrices:")
    @time Kuu, Muu, Kup, fu, fp, tsparse = ElementAssemblyLoop(mesh, ae, be, ze, VxDir, VyDir, SxxNeu, SyyNeu, SxyNeu, SyxNeu, gbar, new)
    println("Sparsification: ", tsparse)

    # Solve for hybrid variable
    println("Linear solve:")
    Kpp = (sparse([1],[1],[0.0],mesh.nel, mesh.nel))
    @time StokesSolvers!(Vxh, Vyh, Pe, mesh, Kuu, Kup, -Kup', Kpp, fu, fp, Muu, solver)

    # Reconstruct element values
    println("Compute element values:")
    @time Vxe, Vye, Txxe, Tyye, Txye = ComputeElementValues(mesh, Vxh, Vyh, Pe, ae, be, ze, VxDir, VyDir)
    println("max. P :  ", maximum(Pe) )

    # Compute discretisation errors
    err_Vx, err_Vy, err_Txx, err_Tyy, err_Txy, err_P, Txxa, Tyya, Txya, Perr_f = ComputeError( mesh, Vxe, Vye, Txxe, Tyye, Txye, Pe, R, eta )
    @printf("Error in Vx : %2.2e\n", err_Vx )
    @printf("Error in Vy : %2.2e\n", err_Vy )
    @printf("Error in Txx: %2.2e\n", err_Txx)
    @printf("Error in Tyy: %2.2e\n", err_Tyy)
    @printf("Error in Txy: %2.2e\n", err_Txy)
    @printf("Error in P  : %2.2e\n", err_P  )

    Perr = abs.(Pa.-Pe) 
    Verr = sqrt.( (Vxe.-Vxa).^2 .+ (Vye.-Vya).^2 ) 
    println("L_inf P error: ", maximum(Perr), " --- L_inf V error: ", maximum(Verr))
    println("L_inf P error: ", maximum(Perr_f), " --- L_inf V error: ", maximum(Verr))

    # Perr_fc= zeros(mesh.nel) 
    # for e=1:mesh.nel
    #     for i=1:mesh.nf_el
    #         nodei = mesh.e2f[e,i]
    #         Perr_fc[e] += 0.25*Perr_f[nodei]
    #     end
    # end

    # Visualise
    # println("Visualisation:")
    # PlotMakie(mesh, v, xmin, xmax, ymin, ymax; cmap = :viridis, min_v = minimum(v), max_v = maximum(v))
    # @time PlotMakie( mesh, Verr, xmin, xmax, ymin, ymax, :jet1, minimum(Verr), maximum(Verr) )
    # @time PlotMakie( mesh, Pe, xmin, xmax, ymin, ymax; cmap=:jet1, min_v =minimum(Pa), max_v =maximum(Pa) )
    @time PlotMakie( mesh, Vye, xmin, xmax, ymin, ymax; cmap=:jet1, min_v =minimum(Vye), max_v =maximum(Vye) )
    # @time PlotMakie( mesh, Vxe, xmin, xmax, ymin, ymax; cmap=:jet1, min_v =minimum(Vxe), max_v =maximum(Vxe) )

    # @time PlotMakie( mesh, Perr, xmin, xmax, ymin, ymax, :jet1, minimum(Perr), maximum(Perr) )
    # @time PlotMakie( mesh, Txxe, xmin, xmax, ymin, ymax, :jet1, -6.0, 2.0 )
    # @time PlotMakie( mesh, mesh.ke, xmin, xmax, ymin, ymax; cmap=:jet1 )
    # @time PlotMakie( mesh, mesh.phase, xmin, xmax, ymin, ymax, :jet1)

    return maximum(Perr)
end

new = 1 
n   = 2
τ   = 1.0
o2  = 0

# main( n, "Quadrangles", 5.0, o2, new )
main( n, "UnstructTriangles", 0.1, o2, new )

# τ    = 1:5:200
# perr = zeros(size(τ))
# for i=1:length(τ)
#     perr[i] = main(τ[i])
# end
# display(Plots.plot(τ, perr, title=minimum(perr))