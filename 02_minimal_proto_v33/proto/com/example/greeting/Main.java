package com.example.greeting;

public class Main {
  public static void main(String[] args) {
    System.out.println(Greeting.newBuilder().setName("world").build());
  }
}
