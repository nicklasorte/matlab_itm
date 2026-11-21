// Reference driver for NTIA ITM v1.4 area mode (ITM_AREA_TLS_Ex).
// Usage: area_driver cases.csv > expected.csv
// cases.csv header: h_tx,h_rx,tx_siting,rx_siting,d_km,delta_h,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include "include/itm.h"
int main(int argc, char **argv) {
    std::ifstream fc(argv[1]); std::string line;
    std::getline(fc, line);   // header
    printf("case,rtn,warnings,A_db,A_ref,A_fs,d_km,delta_h,dh0,dh1,he0,he1,th0,th1,N_s,mode\n");
    int k = 0;
    while (std::getline(fc, line)) {
        if (line.size() < 3) continue;
        std::vector<double> c; std::stringstream ss(line); std::string t;
        while (std::getline(ss, t, ',')) c.push_back(atof(t.c_str()));
        IntermediateValues iv = {}; double A = 0; long w = 0;
        int rtn = ITM_AREA_TLS_Ex(c[0], c[1], (int)c[2], (int)c[3], c[4], c[5], (int)c[6], c[7], c[8], (int)c[9],
            c[10], c[11], (int)c[12], c[13], c[14], c[15], &A, &w, &iv);
        printf("%d,%d,%ld,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%d\n", k, rtn, w, A,
            iv.A_ref__db, iv.A_fs__db, iv.d__km, iv.delta_h__meter, iv.d_hzn__meter[0], iv.d_hzn__meter[1],
            iv.h_e__meter[0], iv.h_e__meter[1], iv.theta_hzn[0], iv.theta_hzn[1], iv.N_s, iv.mode);
        k++;
    }
}
