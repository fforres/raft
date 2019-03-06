# Raft

#### 6.824 Lab 2: Raft
Source: https://pdos.csail.mit.edu/6.824/labs/lab-2.html

All of the base code in this repository can be attributed to MIT's 6.824 distributed systems course. The changes I have made are:
1. Re-structured the `raft` package to work with my `$GOPATH`.
2. Factored all of the essential code for lab 2 into this repository.
3. Created a `Makefile` to make running test commands easier to remember.
3. Filled in all below parts of this lab with my own code.

## Introduction 

This is the first in a series of labs in which you'll build a **fault-tolerant key/value storage system**. In this lab you'll implement Raft, a replicated state machine protocol. In the next lab you'll build a key/value service on top of Raft. Then you will “shard” your service over multiple replicated state machines for higher performance.

A replicated service achieves fault tolerance by storing complete copies of its state (i.e., data) on multiple replica servers. Replication allows the service to continue operating even if some of its servers experience failures (crashes or a broken or flaky network). The challenge is that failures may cause the replicas to hold differing copies of the data.

Raft manages a service's state replicas, and in particular it helps the service sort out what the correct state is after failures. Raft implements a replicated state machine. It organizes client requests into a sequence, called the log, and ensures that all the replicas agree on the contents of the log. Each replica executes the client requests in the log in the order they appear in the log, applying those requests to the replica's local copy of the service's state. Since all the live replicas see the same log contents, they all execute the same requests in the same order, and thus continue to have identical service state. If a server fails but later recovers, Raft takes care of bringing its log up to date. Raft will continue to operate as long as at least a majority of the servers are alive and can talk to each other. If there is no such majority, Raft will make no progress, but will pick up where it left off as soon as a majority can communicate again.

In this lab you'll *implement Raft as a Go object type with associated methods, meant to be used as a module in a larger service. A set of Raft instances talk to each other with RPC to maintain replicated logs*. Your Raft interface will support an indefinite sequence of numbered commands, also called log entries. The entries are numbered with index numbers. The log entry with a given index will eventually be committed. At that point, your Raft should send the log entry to the larger service for it to execute.

> Note: Your Raft instances are only allowed to interact using RPC. For example, different Raft instances are not allowed to share Go variables. Your code should not use files at all.

### Resources

You should consult the [extended Raft paper](https://pdos.csail.mit.edu/6.824/papers/raft-extended.pdf) and the Raft lecture notes. You may find it useful to look at this [illustration](http://thesecretlivesofdata.com/raft/) of the Raft protocol, a [guide](https://thesquareplanet.com/blog/students-guide-to-raft/) to Raft implementation written for 6.824 students in 2016, and advice about [locking](locking) and [structure](https://pdos.csail.mit.edu/6.824/labs/raft-structure.txt) for concurrency. For a wider perspective, have a look at Paxos, Chubby, Paxos Made Live, Spanner, Zookeeper, Harp, Viewstamped Replication, and [Bolosky et al.](http://static.usenix.org/event/nsdi11/tech/full_papers/Bolosky.pdf)

In this lab you'll **implement most of the Raft design described in the extended paper, including saving persistent state and reading it after a node fails and then restarts**. You will not implement cluster membership changes (Section 6) or log compaction / snapshotting (Section 7).

> Hint: Read and understand the extended Raft paper and the Raft lecture notes before you start. Your implementation should follow the paper's description closely, particularly Figure 2, since that's what the tests expect.

## Getting Started

I've restructured the code such that the skeleton code is in `pkg/raft`, and a simple RPC-like system is in `internal/labrpc`.

To get up and running, execute the following:

```sh
$ cd ~/raft
$ make test
# or: go test ./pkg/raft
```

## The Code: pkg/raft

Implement Raft by adding to `pkg/raft.go`. In that file you'll find a bit of skeleton code, plus examples of how to send and receive RPCs.

Your implementation must support the following interface, which the tester and eventually your key/value server will use. 

```go
// create a new Raft server instance:
rf := Make(peers, me, persister, applyCh)

// start agreement on a new log entry
rf.Start(command interface{}) (index, term, isLeader)

// ask a Raft for its current term, and whether it thinks it is leader
rf.GetState() (term, isLeader)

// each time a new entry is commited to the log, each Raft peer
// should send an ApplyMsg to the service (or tester).
type ApplyMsg
```

A service calls `Make(peers, me, ...)` to create a Raft peer. The peers argument is an array of network identifiers of the Raft peers (including this one!), for use with labrpc RPC. The `me` argument is the _index_ of this peer in the peers array. `Start(command)` asks Raft to start the processing to append the command to the replicated log. `Start()` should return immediately, without waiting for the log appends to complete. The service expects your implementation to send an `ApplyMsg` for each newly commited log entry to the `applyCh` argument to `Make()`.

### The Code: internal/labrpc
Your Raft peers should exchange RPCs using the labrpc Go (`internal/labrpc`) package that we provide to you. It is modeled after [Go's rpc library](https://golang.org/pkg/net/rpc/), but internally uses Go channels rather than sockets. `raft.go` contains some example code that sengs an RPC (`sendRequestVote()`) and that handles an incoming RPD (`RequestVote()`). The reason you must use `labrpc` instead of Go's RPC package is that the tester tells `labrpc` to delay RPCs, re-order them, and delete them to simulate challenging network conditions under which your code should work correctly.

## Part 2A

