#include <bits/stdc++.h>
using namespace std;
int main() {
    int n, m;
    cin >> n >> m;
    map<int, vector<int>> mp;
    for (int i = 1; i <= n; i++) {
        int sum = 0, j = i;
        while (j) {
            sum += j % 10;
            j /= 10;
        }
        mp[sum].emplace_back(i);
    }
    int res = [&]() {
        for (const auto& pr : mp) {
            for (int i : pr.second) {
                if (!--m) {
                    return i;
                }
            }
        }
        return 0;
    }();
    cout << res << endl;
    return 0;
}