#include <bits/stdc++.h>
using namespace std;
const int mod = 1e9 + 7;

int main() {
    const int N = 113;
    long long f[N * 2][N][N];  // f[i][j][k]表示走到了第i个位置，遇到了j个花，还剩k斗酒的合法方案数
    f[0][0][2] = 1;  //初始化
    int n, m;
    cin >> n >> m;
    for (int i = 1; i < n + m; i++)
        for (int j = 0; j < m; j++)
            for (int k = 0; k <= m; k++)  //酒的数量不能超过花的数量，否则就算之后一直是花也喝不完
            {
                if (!(k & 1))  // k是偶数，则第i个位置可以是店，否则不可以是店
                    f[i][j][k] = (f[i][j][k] + f[i - 1][j][k >> 1]) % mod;
                if (j >= 1)  //无论k是奇数还是偶数，第i个位置都可以是花
                    f[i][j][k] = (f[i][j][k] + f[i - 1][j - 1][k + 1]) % mod;
            }
    printf("%lld", f[n + m - 1][m - 1][1]);
    return 0;
