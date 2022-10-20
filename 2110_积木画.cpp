#include <cmath>
#include <iostream>
#include <vector>
using namespace std;

const long long MOD = 1e9 + 7;

int main() {
    int n;
    cin >> n;
    vector<int> f(max(3, n)), g(max(3, n));
    f[1] = 1;
    f[2] = 2;
    g[1] = 1;
    g[2] = 2;
    for (int i = 3; i <= n; i++) {
        g[i] = (f[i - 1] + g[i - 1]) % MOD;
        f[i] = ((f[i - 1] + g[i - 1]) % MOD + g[i - 2] % MOD) % MOD;
    }
    cout << f[n] << endl;
    return 0;
}