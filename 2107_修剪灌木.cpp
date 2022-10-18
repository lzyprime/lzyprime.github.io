#include <bits/stdc++.h>
using namespace std;

int main() {
    int n;
    scanf("%d", &n);
    for (int i = 0; i < n; i++) {
        printf("%d\n", max(i, n - i - 1) * 2);
    }
    return 0;
}
