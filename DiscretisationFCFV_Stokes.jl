function ComputeFCFV(mesh, sex, sey, VxDir, VyDir, SxxNeu, SyyNeu, SxyNeu, SyxNeu, tau)
    ae = zeros(mesh.nel)
    be = zeros(mesh.nel,2)
    ze = zeros(mesh.nel,2,2)

    # Assemble FCFV elements
    @tturbo for iel=1:mesh.nel  

        be[iel,1] += mesh.vole[iel]*sex[iel]
        be[iel,2] += mesh.vole[iel]*sey[iel]
        
        for ifac=1:mesh.nf_el
            
            nodei = mesh.e2f[iel,ifac]
            bc    = mesh.bc[nodei]
            dAi   = mesh.dA[iel,ifac]
            ni_x  = mesh.n_x[iel,ifac]
            ni_y  = mesh.n_y[iel,ifac]
            taui  = StabParam(tau,dAi,mesh.vole[iel],mesh.type,mesh.ke[iel])                              # Stabilisation parameter for the face

            # Assemble
            ze[iel,1,1] += (bc==1) * dAi*ni_x*VxDir[nodei] # Dirichlet
            ze[iel,1,2] += (bc==1) * dAi*ni_x*VyDir[nodei] # Dirichlet
            ze[iel,2,1] += (bc==1) * dAi*ni_y*VxDir[nodei] # Dirichlet
            ze[iel,2,2] += (bc==1) * dAi*ni_y*VyDir[nodei] # Dirichlet
            be[iel,1]   += (bc==1) * dAi*taui*VxDir[nodei] # Dirichlet
            be[iel,2]   += (bc==1) * dAi*taui*VyDir[nodei] # Dirichlet
            ae[iel]     +=           dAi*taui
            
        end
    end
    return ae, be, ze
end

#--------------------------------------------------------------------#

function ComputeElementValues(mesh, Vxh, Vyh, Pe, ae, be, ze, VxDir, VyDir, tau)
    Vxe         = zeros(mesh.nel);
    Vye         = zeros(mesh.nel);
    Txxe        = zeros(mesh.nel);
    Tyye        = zeros(mesh.nel);
    Txye        = zeros(mesh.nel);

    @tturbo for iel=1:mesh.nel
    
        Vxe[iel]  =  be[iel,1]/ae[iel]
        Vye[iel]  =  be[iel,2]/ae[iel]
        Txxe[iel] =  mesh.ke[iel]/mesh.vole[iel]*ze[iel,1,1]
        Tyye[iel] =  mesh.ke[iel]/mesh.vole[iel]*ze[iel,2,2] 
        Txye[iel] =  mesh.ke[iel]/mesh.vole[iel]*0.5*(ze[iel,1,2]+ze[iel,2,1])
        
        for ifac=1:mesh.nf_el
            
            # Face
            nodei = mesh.e2f[iel,ifac]
            bc    = mesh.bc[nodei]
            dAi   = mesh.dA[iel,ifac]
            ni_x  = mesh.n_x[iel,ifac]
            ni_y  = mesh.n_y[iel,ifac]
            taui  = StabParam(tau,dAi,mesh.vole[iel],mesh.type,mesh.ke[iel])      # Stabilisation parameter for the face

            # Assemble
            Vxe[iel]  += (bc!=1) *  dAi*taui*Vxh[nodei]/ae[iel]
            Vye[iel]  += (bc!=1) *  dAi*taui*Vyh[nodei]/ae[iel]
            Txxe[iel] += (bc!=1) *  mesh.ke[iel]/mesh.vole[iel]*dAi*ni_x*Vxh[nodei]
            Tyye[iel] += (bc!=1) *  mesh.ke[iel]/mesh.vole[iel]*dAi*ni_y*Vyh[nodei]
            Txye[iel] += (bc!=1) *  mesh.ke[iel]*0.5*( 1.0/mesh.vole[iel]*dAi*( ni_x*Vyh[nodei] + ni_y*Vxh[nodei] ) )
         end
        Txxe[iel] *= 2.0
        Tyye[iel] *= 2.0
        Txye[iel] *= 2.0
    end
    return Vxe, Vye, Txxe, Tyye, Txye
end

#--------------------------------------------------------------------#

function ElementAssemblyLoop(mesh, ae, be, ze, VxDir, VyDir, SxxNeu, SyyNeu, SxyNeu, SyxNeu, gbar, tau)
    # Assemble element matrices and rhs
    f   = zeros(mesh.nf)
    Kuu = zeros(mesh.nel, 2*mesh.nf_el, 2*mesh.nf_el)
    fu  = zeros(mesh.nel, 2*mesh.nf_el)
    Kup = zeros(mesh.nel, 2*mesh.nf_el);
    fp  = zeros(mesh.nel)

    @tturbo for iel=1:mesh.nel 

        for ifac=1:mesh.nf_el 

            nodei = mesh.e2f[iel,ifac]
            bci   = mesh.bc[nodei]
            dAi   = mesh.dA[iel,ifac]
            ni_x  = mesh.n_x[iel,ifac]
            ni_y  = mesh.n_y[iel,ifac]
            taui  = StabParam(tau,dAi,mesh.vole[iel], mesh.type,mesh.ke[iel])  
                
            for jfac=1:mesh.nf_el

                nodej = mesh.e2f[iel,jfac]
                bcj   = mesh.bc[nodej]   
                dAj   = mesh.dA[iel,jfac]
                nj_x  = mesh.n_x[iel,jfac]
                nj_y  = mesh.n_y[iel,jfac]
                tauj  = StabParam(tau,dAj,mesh.vole[iel], mesh.type,mesh.ke[iel])  
                        
                # Delta
                del = 0.0 + (ifac==jfac)*1.0
                        
                # Element matrix
                nitnj = ni_x*nj_x + ni_y*nj_y;
                Ke_ij =-dAi * (1.0/ae[iel] * dAj * taui*tauj - mesh.ke[iel]/mesh.vole[iel]*dAj*nitnj - taui*del)
                yes   = (bci!=1) & (bcj!=1)
                Kuu[iel,ifac,           jfac           ] = yes * Ke_ij
                Kuu[iel,ifac+mesh.nf_el,jfac+mesh.nf_el] = yes * Ke_ij
                # Kuu[iel,ifac,           jfac           ] = (bci!=1) * (bcj!=1) * Ke_ij
                # Kuu[iel,ifac+mesh.nf_el,jfac+mesh.nf_el] = (bci!=1) * (bcj!=1) * Ke_ij
            end
            # RHS
            Xi      = 0.0 + (bci==2)*1.0
            Ji      = 0.0 + (bci==3)*1.0
            tix     = ni_x*SxxNeu[nodei] + ni_y*SxyNeu[nodei]
            tiy     = ni_x*SyxNeu[nodei] + ni_y*SyyNeu[nodei]
            nitze_x = ni_x*ze[iel,1,1] + ni_y*ze[iel,2,1]
            nitze_y = ni_x*ze[iel,1,2] + ni_y*ze[iel,2,2]
            feix    = (bci!=1) * -dAi * (mesh.ke[iel]/mesh.vole[iel]*nitze_x - tix*Xi - gbar[iel,ifac,1]*Ji - 1.0/ae[iel]*be[iel,1]*taui)
            feiy    = (bci!=1) * -dAi * (mesh.ke[iel]/mesh.vole[iel]*nitze_y - tiy*Xi - gbar[iel,ifac,2]*Ji - 1.0/ae[iel]*be[iel,2]*taui)
            # up block
            Kup[iel,ifac]                            -= (bci!=1) * dAi*ni_x;
            Kup[iel,ifac+mesh.nf_el]                 -= (bci!=1) * dAi*ni_y;
            # Dirichlet nodes - uu block
            Kuu[iel,ifac,ifac]                       += (bci==1) * 1e6
            Kuu[iel,ifac+mesh.nf_el,ifac+mesh.nf_el] += (bci==1) * 1e6
            fu[iel,ifac]                             += (bci!=1) * feix + (bci==1) * VxDir[nodei] * 1e6
            fu[iel,ifac+mesh.nf_el]                  += (bci!=1) * feiy + (bci==1) * VyDir[nodei] * 1e6
            # Dirichlet nodes - pressure RHS
            fp[iel]                                  += (bci==1) * -dAi*(VxDir[nodei]*ni_x + VyDir[nodei]*ni_y)
        end
    end
    return Kuu, fu, Kup, fp
end

#--------------------------------------------------------------------#

function CreateTripletsSparse(mesh, Kuu_v, fu_v, Kup_v)
    # Create triplets and assemble sparse matrix fo Kuu
    e2fu = mesh.e2f
    e2fv = mesh.e2f .+ mesh.nf 
    e2f  = hcat(e2fu, e2fv)
    idof = 1:mesh.nf_el*2  
    ii   = repeat(idof, 1, length(idof))'
    ij   = repeat(idof, 1, length(idof))
    Ki   = e2f[:,ii]
    Kif  = e2f[:,ii[1,:]]
    Kj   = e2f[:,ij]
    @time Kuu  = sparse(Ki[:], Kj[:], Kuu_v[:], mesh.nf*2, mesh.nf*2)
    # file = matopen(string(@__DIR__,"/results/matrix_uu.mat"), "w" )
    # write(file, "Ki",       Ki[:] )
    # write(file, "Kj",    Kj[:] )
    # write(file, "Kuu",  Kuu_v[:] )
    # write(file, "nrow",  mesh.nf*2 )
    # write(file, "ncol",  mesh.nf*2 )
    # close(file)
    @time fu   = sparse(Kif[:], ones(size(Kif[:])), fu_v[:], mesh.nf*2, 1)
    u   = Array(fu)
    droptol!(Kuu, 1e-6)
    # Create triplets and assemble sparse matrix fo Kup
    idof = 1:mesh.nf_el*2  
    ii   = repeat(idof, 1, mesh.nel)'
    ij   = repeat(1:mesh.nel, 1, length(idof))
    Ki   = e2f
    Kj   = ij
    @time Kup  = sparse(Ki[:], Kj[:], Kup_v[:], mesh.nf*2, mesh.nel  )
    # file = matopen(string(@__DIR__,"/results/matrix_up.mat"), "w" )
    # write(file, "Ki",       Ki[:] )
    # write(file, "Kj",    Kj[:] )
    # write(file, "Kup",  Kup_v[:] )
    # write(file, "nrow",  mesh.nf*2 )
    # write(file, "ncol",  mesh.nel )
    # close(file)
    return Kuu, fu, Kup
end

#--------------------------------------------------------------------#