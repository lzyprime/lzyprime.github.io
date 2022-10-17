#include <bits/stdc++.h>
using namespace std;

int cmp(const void* a, const void* b) {
  return *((char*)a) - *((char*)b);
}
int main()
{
  char a[] = "WHERETHEREISAWILLTHEREISAWAY";
  qsort(a, strlen(a), sizeof(char), cmp);
  printf("%s\n", a);
  return 0;
}