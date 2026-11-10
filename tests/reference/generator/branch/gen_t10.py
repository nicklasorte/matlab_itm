import sys, random
R=random.Random(int(sys.argv[1])); N=int(sys.argv[2]); out=sys.argv[3]
with open(out+'_pfls.csv','w') as fp, open(out+'_cases.csv','w') as fc:
  fc.write('h_tx,h_rx,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation,pfl_idx\n')
  for k in range(N):
    d=R.uniform(400e3,2000e3); np_=R.choice([500,1000,2000,4000]); xi=d/np_
    Ht=R.uniform(0,9000); Z=R.uniform(0,R.choice([9000,20000,60000]))
    jobs=np_-R.randint(1,5)
    z=[Ht]+[0.0]*(np_)
    z[jobs]=Z
    if R.random()<0.5: z[1]=Ht*R.random()
    fp.write(','.join('%.17g'%v for v in [np_,xi]+z)+'\n')
    h1=R.uniform(0.5,3000); h2=R.uniform(0.5,50)
    f=10**R.uniform(1.4,4.3); N0=R.uniform(350,400)
    fc.write(','.join('%.17g'%v for v in [h1,h2,R.randint(1,7),N0,f,R.randint(0,1),80,5,0,50,50,50,k])+'\n')
