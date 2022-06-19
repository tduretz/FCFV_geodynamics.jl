 # The following functions are borrowed from MILAMIN_1.0.1
function IntegrationTriangle( nip )
    ipx = zeros(nip,2)
    ipw = zeros(nip,1)
    if nip == 1
        # Location
        ipx[1,1] = 1/3
        ipx[1,2] = 1/3
        # Weight
        ipw[1]   = 0.5
    elseif nip == 3
        # Location
        ipx[1,1] = 1/6
        ipx[1,2] = 1/6
        ipx[2,1] = 2/3
        ipx[2,2] = 1/6
        ipx[3,1] = 1/6
        ipx[3,2] = 2/3
        # Weight    
        ipw[1] = 1/6
        ipw[2] = 1/6
        ipw[3] = 1/6
    elseif nip == 6
        g1 = (8-sqrt(10) + sqrt(38-44*sqrt(2/5)))/18;
        g2 = (8-sqrt(10) - sqrt(38-44*sqrt(2/5)))/18;
        ipx[1,1] = 1-2*g1;                  #0.108103018168070;
        ipx[1,2] = g1;                      #0.445948490915965;
        ipx[2,1] = g1;                      #0.445948490915965;
        ipx[2,2] = 1-2*g1;                  #0.108103018168070;
        ipx[3,1] = g1;                      #0.445948490915965;
        ipx[3,2] = g1;                      #0.445948490915965;
        ipx[4,1] = 1-2*g2;                  #0.816847572980459;
        ipx[4,2] = g2;                      #0.091576213509771;
        ipx[5,1] = g2;                      #0.091576213509771;
        ipx[5,2] = 1-2*g2;                  #0.816847572980459;
        ipx[6,1] = g2;                      #0.091576213509771;
        ipx[6,2] = g2;                      #0.091576213509771;

        w1 = (620+sqrt(213125-53320*sqrt(10)))/3720;
        w2 = (620-sqrt(213125-53320*sqrt(10)))/3720;
        ipw[1] =  w1;                       #0.223381589678011;
        ipw[2] =  w1;                       #0.223381589678011;
        ipw[3] =  w1;                       #0.223381589678011;
        ipw[4] =  w2;                       #0.109951743655322;
        ipw[5] =  w2;                       #0.109951743655322;
        ipw[6] =  w2;                       #0.109951743655322;
        ipw     = 0.5*ipw;

    end
    return ipx, ipw
end

function ShapeFunctions(ipx, nip, nnel)

    N    = zeros(nip,nnel,1)
    dNdx = zeros(nip,nnel,2)

    for i=1:nip
        # Local coordinates of integration points
        η2 = ipx[i,1]
        η3 = ipx[i,2]
        η1 = 1.0-η2-η3
        if nnel==3
            N[i,:,:]    .= [η1 η2 η3]'
            dNdx[i,:,:] .= [-1. 1. 0.;  #w.r.t η2
                            -1. 0. 1.]' #w.r.t η3
        elseif nnel==6
            N[i,:,:]    .= [η1*(2*η1-1) η2*(2*η2-1) η3*(2*η3-1) 4*η2*η3  4*η1*η3    4*η1*η2]'
            dNdx[i,:,:] .= [1-4*η1      -1+4*η2     0.          4*η3    -4*η3       4*η1-4*η2;  #w.r.t η2
                            1-4*η1      0.          -1+4*η3     4*η2     4*η1-4*η3 -4*η2]'      #w.r.t η3
        elseif nnel==7
            N[i,:,:]    .= [η1*(2*η1-1)+3*η1*η2*η3  η2*(2*η2-1)+3*η1*η2*η3  η3*(2*η3-1)+3*η1*η2*η3 4*η2*η3-12*η1*η2*η3     4*η1*η3-12*η1*η2*η3           4*η1*η2-12*η1*η2*η3          27*η1*η2*η3]'
            dNdx[i,:,:] .= [1-4*η1+3*η1*η3-3*η2*η3 -1+4*η2+3*η1*η3-3*η2*η3  3*η1*η3-3*η2*η3        4*η3+12*η2*η3-12*η1*η3 -4*η3+12*η2*η3-12*η1*η3        4*η1-4*η2+12*η2*η3-12*η1*η3 -27*η2*η3+27*η1*η3;  #w.r.t η2
                            1-4*η1+3*η1*η2-3*η2*η3 +3*η1*η2-3*η2*η3        -1+4*η3+3*η1*η2-3*η2*η3 4*η2-12*η1*η2+12*η2*η3  4*η1-4*η3-12*η1*η2+12*η2*η3  -4*η2-12*η1*η2+12*η2*η3       27*η1*η2-27*η2*η3]' #w.r.t η3
        end
    end

    return N, dNdx

end