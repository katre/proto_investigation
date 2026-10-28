package com.example.greeter;

import io.grpc.stub.StreamObserver;

/** Trivial consumer that implements the generated service. */
public final class Main {
  static final class Impl extends GreeterGrpc.GreeterImplBase {
    @Override
    public void sayHello(HelloRequest req, StreamObserver<HelloReply> out) {
      out.onNext(HelloReply.newBuilder().setMessage("Hello, " + req.getName()).build());
      out.onCompleted();
    }
  }

  public static void main(String[] args) {
    System.out.println(GreeterGrpc.getServiceDescriptor().getName());
  }
}
