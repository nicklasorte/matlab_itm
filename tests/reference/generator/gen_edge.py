# Exact-boundary cases for WS3 (tests/reference/edge_*). Deterministic.
H="h_tx,h_rx,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation,pfl_idx"
P=[]
def prof(np_, xi, z):
    assert len(z) == np_ + 1, (np_, len(z))
    P.append([np_, xi]+z); return len(P)-1
rough=prof(100, 500, [200+50*((i*37)%11)-30*((i*13)%7) for i in range(101)])   # 50 km rolling
flat_short=prof(10, 1, [0]*11)                    # 10 m path
flat_1km=prof(10, 100, [0]*11)                    # 1 km
sea_2100=prof(210, 10000, [0]*211)               # 2,100 km over sea
tie=prof(20, 1000, [0]*5+[300]+[0]*9+[300]+[0]*5) # two equal peaks: horizon tie
np1=prof(1, 5000, [10, 40])
ridge_at_rx=prof(20, 500, [0]*19+[500,0])         # obstacle next to the receiver
base=dict(h1=30,h2=10,clim=5,N0=301,f=1000,pol=1,eps=15,sig=0.005,md=12,t=50,l=50,s=50,p=rough)
C=[]
def case(**kw):
    d=dict(base); d.update(kw); C.append([d[k] for k in ['h1','h2','clim','N0','f','pol','eps','sig','md','t','l','s','p']])
for h in [0.5, 0.49999999, 1, 1000, 3000, 3000.0000001]:
    case(h1=h); case(h2=h)
for f in [20, 19.999999, 40, 10000, 20000, 20000.00001]: case(f=f)
for n in [250, 249.9999, 400, 400.0001]: case(N0=n)
for t in [0.01, 99.99]:
    case(t=t); case(l=t); case(s=t)
for c in range(1,8): case(clim=c)
for md in [0,1,2,3,10,11,12,13,20,21,22,23,30,31,32,33]: case(md=md)
case(eps=1, pol=1); case(eps=1, pol=0); case(eps=1.0000001, pol=0); case(sig=1e-12); case(sig=1e4, f=20, pol=1, eps=80)
for p in [flat_short, flat_1km, sea_2100, tie, np1, ridge_at_rx]:
    case(p=p); case(p=p, h1=3000, h2=0.5); case(p=p, f=20000, pol=0)
open('edge_pfls.csv','w').write('\n'.join(','.join('%.17g'%v for v in p) for p in P)+'\n')
open('edge_cases.csv','w').write(H+'\n'+'\n'.join(','.join('%.17g'%v for v in c) for c in C)+'\n')
print(len(C),'cases',len(P),'profiles')
