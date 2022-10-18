#include <iostream>
#include <vector>
using namespace std;
int main() {
    int n, m, k;
    cin >> n >> m >> k;
    vector<vector<int>> a(n + 1, vector<int>(m + 1, 0));
    for (int i = 1; i <= n; i++) {
        for (int j = 1; j <= m; j++) {
            cin >> a[i][j];
            a[i][j] += a[i - 1][j];
        }
    }
    unsigned long long res = 0;
    for (int i = 1; i <= n; i++) {
        for (int j = i; j <= n; j++) {
            int sum = 0;
            for (int l = 1, r = 1; r <= m; r++) {
                sum += a[j][r] - a[i - 1][r];
                if (sum <= k) {
                    res += r - l + 1;
                } else {
                    while (sum > k && l <= r) {
                        sum -= a[j][l] - a[i - 1][l];
                        l++;
                    }
                    res += r - l + 1;
                }
            }
        }
    }
    cout << res << endl;
    return 0;
}