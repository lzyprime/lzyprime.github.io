/**
map<int, map<int, unordered_map<int, int>>> mp;,    按<x, <y, <r, count>>> 存雷；
读入 扫雷火箭 x,y,r。  
找在(x-r, x+r), (y-r,y+r) 方形内的雷，剪枝操作。  

然后进一步判这个范围内的点(xi, yi)是否在半径内。
如果在, 遍历 mp[xi][yi]; 
队列中暂存雷(xi, yi, ri)，结果加上该点的雷数 res += mp[xi][yi][ri]。 

对队列中的点继续如上查找，直到没有雷被覆盖。
*/

#include <bits/stdc++.h>
using namespace std;

const int fff = []() {ios::sync_with_stdio(false); cin.tie(nullptr); cout.tie(nullptr); return 0; }();

bool is_in_scope(long long x1, long long y1, long long r, long long x2, long long y2) {
    return (x1 - x2) * (x1 - x2) <= r * r - (y1 - y2) * (y1 - y2);
}

int main() {
    int n, m;
    cin >> n >> m;
    map<int, map<int, unordered_map<int, int>>> mp;
    for (int i = 0; i < n; i++) {
        int x, y, r;
        cin >> x >> y >> r;
        mp[x][y][r]++;
    }
    int res = 0;
    for (int i = 0; i < m; i++) {
        int x, y, r;
        cin >> x >> y >> r;
        queue<tuple<int, int, int>> q;
        q.emplace(x, y, r);
        while (!q.empty()) {
            x = get<0>(q.front());
            y = get<1>(q.front());
            r = get<2>(q.front());
            q.pop();
            for (auto xiter = mp.lower_bound(x - r), xed = mp.upper_bound(x + r); xiter != xed;) {
                for (auto yiter = xiter->second.lower_bound(y - r), yed = xiter->second.upper_bound(y + r); yiter != yed;) {
                    if (is_in_scope(x, y, r, xiter->first, yiter->first)) {
                        for(const auto& bm:yiter->second) {
                            res += bm.second;
                            q.emplace(xiter->first, yiter->first, bm.first);
                        }
                        yiter = xiter->second.erase(yiter);
                    } else {
                        yiter++;
                    }
                }
                if(xiter->second.empty()) {
                    xiter = mp.erase(xiter);
                } else {
                    xiter++;
                }
            }
        }
    }
    cout << res << endl;
    return 0;
}