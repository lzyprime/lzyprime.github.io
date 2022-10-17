/**
直接数：
row 行
column 列

边需要4刀，分离 row 行需要 row - 1 刀, 分离 column 列需要 column - 1 刀，每行都要处理column列， 所以列总共需要 (column - 1) * row.

总： 4 + (row - 1) + (column - 1) * row
*/

#include <iostream>
using namespace std;

int main() {
    int row = 20, column = 22;
    printf("%d\n", 4 + (row - 1) + (column - 1) * row);
    return 0;
}