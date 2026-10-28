#include <iostream>

#include "proto/greeting.pb.h"

int main() {
  greeting::Greeting g;
  g.set_name("world");
  std::cout << g.DebugString();
  return 0;
}
