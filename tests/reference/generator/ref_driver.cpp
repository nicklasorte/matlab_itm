// Reference generator: runs NTIA ITM v1.4 ITM_P2P_TLS_Ex for every case.
// Input:  cases.csv  (h_tx,h_rx,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation,pfl_idx)
//         pfls.csv   (one profile per line, PFL format: np,xi,z0..znp)
// Output: stdout CSV: case_idx,rtn,warnings,A_db,A_ref,A_fs,d_km,delta_h,dh0,dh1,he0,he1,th0,th1,N_s,mode
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include "include/itm.h"

static std::vector<double> split(const std::string& s)
{
    std::vector<double> v; std::stringstream ss(s); std::string tok;
    while (std::getline(ss, tok, ',')) if (!tok.empty()) v.push_back(atof(tok.c_str()));
    return v;
}

int main(int argc, char** argv)
{
    std::ifstream fp(argv[2]); std::string line;
    std::vector<std::vector<double>> pfls;
    while (std::getline(fp, line)) if (line.size() > 2) pfls.push_back(split(line));
    std::ifstream fc(argv[1]);
    std::getline(fc, line); // header
    int k = 0;
    printf("case,rtn,warnings,A_db,A_ref,A_fs,d_km,delta_h,dh0,dh1,he0,he1,th0,th1,N_s,mode\n");
    while (std::getline(fc, line))
    {
        if (line.size() < 2) continue;
        std::vector<double> c = split(line);
        const std::vector<double>& p = pfls[(int)c[12]];
        double A = 0; long w = 0; IntermediateValues iv = {};
        int rtn = ITM_P2P_TLS_Ex(c[0], c[1], p.data(), (int)c[2], c[3], c[4], (int)c[5], c[6], c[7], (int)c[8],
                                 c[9], c[10], c[11], &A, &w, &iv);
        printf("%d,%d,%ld,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%d\n",
               k, rtn, w, A, iv.A_ref__db, iv.A_fs__db, iv.d__km, iv.delta_h__meter, iv.d_hzn__meter[0], iv.d_hzn__meter[1],
               iv.h_e__meter[0], iv.h_e__meter[1], iv.theta_hzn[0], iv.theta_hzn[1], iv.N_s, iv.mode);
        k++;
    }
    return 0;
}
