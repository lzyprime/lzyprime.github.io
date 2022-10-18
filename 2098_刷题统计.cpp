#include <iostream>
using namespace std;
int main() {
    long long a, b, n;
    cin >> a >> b >> n;
    long long week = 5 * a + 2 * b, res = (n / week) * 7;
    n %= week;
    while (n > 0) {
        res++;
        if (res % 7 == 6 || res % 7 == 0) {
            n -= b;
        } else {
            n -= a;
        }
    }
    cout << res << endl;
    return 0;
}