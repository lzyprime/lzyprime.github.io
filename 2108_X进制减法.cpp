#include <iostream>
#include <vector>
using namespace std;

const long long mod = 1e9 + 7;

int main() {
    int n, m1, m2;
    cin >> n >> m1;
    vector<int> a1(m1), a2(m1);
    for (int i = m1 - 1; i >= 0; i--) {
        cin >> a1[i];
    }
    cin >> m2;
    for (int i = m2 - 1; i >= 0; i--) {
        cin >> a2[i];
    }
    long long res = 0, x = 1;
    for (int i = 0; i < m1; i++) {
        res = ((a1[i] - a2[i]) * x + res) % mod;
        x = max(2, max(a1[i], a2[i]) + 1) * x % mod;
    }
    cout << res << endl;
    return 0;
}