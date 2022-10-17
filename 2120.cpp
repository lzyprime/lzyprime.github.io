#include <bits/stdc++.h>
using namespace std;

int main() {
    int n;
    scanf("A%d", &n);
    int l1 = 1189, l2 = 841;
    for (int i = 0; i < n; i++) {
        if (l1 > l2) {
            l1 /= 2;
        } else {
            l2 /= 2;
        }
    }
    if (l1 > l2) {
        printf("%d\n%d\n", l1, l2);
    } else {
        printf("%d\n%d\n", l2, l1);
    }
    return 0;
}