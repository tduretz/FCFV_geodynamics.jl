ENV["MPLBACKEND"]="Qt5Agg"
# Problem #1 was to find a simple way to plot piecewise constant fields on triangles:
# solution from: https://robertsweeneyblanco.github.io/Programming_for_Mathematical_Applications/Computational_Geometry/Triangulations.html
# Problem #2 was to get any figures popping out in VScode 
# and: https://github.com/JuliaPy/PyPlot.jl/issues/418
using PyPlot
using Base.Threads
using LoopVectorization
import TriangleMesh
using Printf
pygui(true)

#--------------------------------------------------------------------#

function tplot(p, t, v)
    # Plot triangular mesh with nodes `p` and triangles `t`
    # clf()
    # tris = convert(Array{Int64}, hcat(t...)')
    # display(tripcolor(first.(p), last.(p), tris .- 1, v,
    #           cmap="viridis", edgecolors="none", linewidth=0) )
    # axis("equal")
    # ylim([0, 1])
    # xlim([0, 1])
    # title("Low res.")
    # xlabel("x")
    # ylabel("y")
    # colorbar()
    # show()
    return 
end

function Tanalytic!( mesh, xc , yc, T, nvert_ele, a, b, c, d, alp, bet, vec )
    # Evaluate T analytic on barycentres: vec 0 or 1
    if vec==0 # Loop version vectorized at compilation using @avx
        @avx for i=1:mesh.n_cell
            xc[i] = 0;
            yc[i] = 0;
            for j=1:nvert_ele
                xc[i] += 1.0/nvert_ele*( mesh.point[1,mesh.cell[j,i]] )
                yc[i] += 1.0/nvert_ele*( mesh.point[2,mesh.cell[j,i]] )
            end
        end
        @avx for i=1:mesh.n_cell
            T[i] = exp(alp.sin(a*xc[i] + c*yc[i]) + bet*cos(b*xc[i] + d*yc[i]));
        end
    else # Standard vectorization
        # X    = mesh.point[1,mesh.cell[:,:]]'  # X coordinates of vertices of each element
        # Y    = mesh.point[2,mesh.cell[:,:]]'  # Y coordinates of vertices of each element
        # sumX = sum(X, dims=2)
        # sumY = sum(Y, dims=2)
        # @. xc = 1.0/nvert_ele * sumX[:]
        # @. yc = 1.0/nvert_ele * sumY[:]
    for j=1:nvert_ele # as fast as above and less cryptic
        @. xc = 0.0
        @. yc = 0.0
        @. xc = xc + 1.0/nvert_ele * mesh.point[1,mesh.cell[j,:]] 
        @. yc = yc + 1.0/nvert_ele * mesh.point[2,mesh.cell[j,:]] 
    end
    @. T = exp(alp*sin(a*xc + c*yc) + bet*cos(b*xc + d*yc));
end
return
end

#--------------------------------------------------------------------#

function main()

# Create sides of mesh
xmin, xmax = 0, 1
ymin, ymax = 0, 1
nx, ny     = 20, 20 

# Four corners of the domain
px = [0.0 1.0 1.0 0.0]
py = [0.0 0.0 1.0 1.0]
sx = [ 1 2 3 4 ] 
sy = [ 2 3 4 1 ]
st = [ 1 1 1 1 ]          # segment markers
p  = vcat(px, py)         # points
s  = vcat(sx, sy)         # segments

# TriangleMesh.Polygon_pslg:
# n_point           :: Int32
# point             :: Array{Float64,2}
# n_point_marker    :: Int32
# point_marker      :: Array{Int32,2}
# n_point_attribute :: Int32
# point_attribute   :: Array{Float64,2}
# n_segment         :: Int32
# segment           :: Array{Int32,2}
# segment_marker    :: Array{Int32,1}
# n_hole            :: Int32
# hole              :: Array{Float64,2}

# Triangulation
holes    = Array{Float64}(undef,2,0)
domain   = TriangleMesh.Polygon_pslg(size(p,2), p, 0, Array{Int64}(undef,2,0), 0, Array{Float64}(undef,2,0),  size(s,2), s, st[:], 0, holes)
switches = "Dpenq33IAa0.01"#"Dpenq33o2IAa"
mesh     = TriangleMesh.create_mesh(domain, switches)
nvert_el = 3 # vertices per element
println(size(mesh.cell))

# Prepare mesh for visalisation
p1 = fill(Float64[], size(mesh.point,2))
for i=1:size(mesh.point,2)
    p1[i] = [mesh.point[1,i], mesh.point[2,i]]
end
t1 = fill(Int64[], size(mesh.cell,2))
for i=1:size(mesh.cell,2)
    t1[i] = [mesh.cell[1,i], mesh.cell[2,i], mesh.cell[3,i]]
end

# Generate function to be visualised on mesh
alp = 0.1; bet = 0.3; a = 5.1; b = 4.3; c = -6.2; d = 3.4;
xc = zeros(mesh.n_cell)
yc = zeros(mesh.n_cell)
T  = zeros(mesh.n_cell)
ncalls = 4
# A) Loop version with @avx
vec = 0
@printf("Looped, %d times:\n", ncalls)
for icall=1:ncalls
    @time Tanalytic!(mesh, xc ,yc , T, nvert_el, a, b, c, d, alp, bet, vec)
end
# B) Standard vectorisation
vec = 1
@printf("Vectorized, %d times:\n", ncalls)
for icall=1:ncalls
    @time Tanalytic!(mesh, xc ,yc , T, nvert_el, a, b, c, d, alp, bet, vec)
end
# # Visualise
tplot(p1, t1, T) 

println(typeof(t1))
println(typeof(p1))

return
end

main()
