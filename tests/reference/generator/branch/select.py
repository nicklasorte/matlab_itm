import csv
H="h_tx,h_rx,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation,pfl_idx"
pf_out=[]; c_out=[]
def add(prof_line, case_vals):
    pf_out.append(prof_line); v=case_vals[:12]+[str(len(pf_out)-1)]; c_out.append(','.join(v))
sources=['b1','b2','b3','b4','t10']
pick={b:[] for b in [0,3,4,5,6,7,8,9,10]}
for s in sources:
    pf=open(s+'_pfls.csv').read().splitlines(); cs=open(s+'_cases.csv').read().splitlines()[1:]
    for r in csv.DictReader(open(s+'_out.csv')):
        if r['rtn'] not in('0','1'): continue
        k=int(r['case']); h=int(r['hits']); cv=cs[k].split(',')
        np_=int(float(pf[k].split(',')[0]))
        for b in pick:
            if h>>b&1: pick[b].append((np_, s, k, cv[8], r['mode'], h))
chosen=set()
for b,L in pick.items():
    L.sort(); seen_md=set(); n=0
    for np_,s,k,md,mode,h in L:
        if (s,k) in chosen or (md,mode) in seen_md: continue
        chosen.add((s,k)); seen_md.add((md,mode)); n+=1
        pf=open(s+'_pfls.csv').read().splitlines()[k]; cv=open(s+'_cases.csv').read().splitlines()[1:][k].split(',')
        add(pf,cv)
        if n==4: break
    print('target bit',b,'picked',n,'from',len(L))
# extras: np=1 and error codes
xp=open('x_pfls.csv').read().splitlines(); xc=open('x_cases.csv').read().splitlines()[1:]
for c in xc:
    cv=c.split(','); add(xp[int(cv[12])], cv)
open('branch_pfls.csv','w').write('\n'.join(pf_out)+'\n')
open('branch_cases.csv','w').write(H+'\n'+'\n'.join(c_out)+'\n')
print(len(c_out),'cases')
