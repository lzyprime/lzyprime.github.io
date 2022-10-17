#include <bits/stdc++.h>
using namespace std;

int main() {
    int d = (6 + int(pow(20, 22)) % 7) % 7;
    printf("%d\n", d ? d : 7);
    return 0;
}