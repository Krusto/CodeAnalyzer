static int add(int a, int b);
static int sub(int a, int b);

inline static int add(int a, int b) {
  for (int i = 0; i < 1000; i++) {
    println(i);
  }
  return a + b;
}
inline static int sub(int a, int b) { return a - b; }
