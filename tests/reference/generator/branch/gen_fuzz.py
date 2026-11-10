import sys, random, math
seed=int(sys.argv[1]); N=int(sys.argv[2]); out=sys.argv[3]
R=random.Random(seed)
def prof():
    np_=R.choice([2,3,4,5,8,10,20,50,100,R.randint(2,800)])
    d=10**R.uniform(1.5,6.5)  # 30 m .. 3160 km
    if R.random()<0.15: d=R.uniform(1.0e6,3.0e6)
    xi=d/np_
    kind=R.choice(['flat','walk','pits','towers','bowl','ramp','sine','extreme','dome'])
    A=10**R.uniform(-1,3.6); base=R.uniform(-50,3000)
    z=[]
    for i in range(np_+1):
        t=i/np_
        if kind=='flat': h=base
        elif kind=='walk': h=(z[-1] if z else base)+R.gauss(0,A/math.sqrt(np_+1))
        elif kind=='pits': h=base-(A if R.random()<R.uniform(0.05,0.5) else 0)
        elif kind=='towers': h=base+(A if R.random()<R.uniform(0.02,0.3) else 0)
        elif kind=='bowl': h=base+A*(2*t-1)**2
        elif kind=='dome': h=base+A*(1-(2*t-1)**2)
        elif kind=='ramp': h=base+A*t*R.choice([1,-1])
        elif kind=='sine': h=base+A*math.sin(2*math.pi*t*R.uniform(0.5,20))
        else: h=base+R.uniform(-A,A)*3
        z.append(h)
    if kind in('pits','towers','bowl') and R.random()<0.5: z[0]=z[-1]=base
    return [np_,xi]+z
with open(out+'_pfls.csv','w') as fp, open(out+'_cases.csv','w') as fc:
    fc.write('h_tx,h_rx,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation,pfl_idx\n')
    for k in range(N):
        p=prof(); fp.write(','.join('%.17g'%v for v in p)+'\n')
        h1=10**R.uniform(-0.3,3.5); h2=10**R.uniform(-0.3,3.5)
        f=10**R.uniform(math.log10(20),math.log10(20000))
        if R.random()<0.1: f=R.choice([20,20000,40,10000])
        clim=R.randint(1,7); N0=R.uniform(250,400); pol=R.randint(0,1)
        eps=10**R.uniform(0,2); sig=10**R.uniform(-5,2)
        mdvar=R.choice([0,1,2,3,10,11,12,13,20,21,22,23]); 
        t=R.choice([0.01,1,10,50,90,99,99.99]); l=R.choice([0.01,50,99.99]); s=R.choice([0.01,50,99.99])
        fc.write(','.join('%.17g'%v for v in [h1,h2,clim,N0,f,pol,eps,sig,mdvar,t,l,s,k])+'\n')
