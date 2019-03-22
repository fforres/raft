# Raft

#### 6.824 Lab 2: Raft
Source: https://pdos.csail.mit.edu/6.824/labs/lab-2.html

All of the base code in this repository can be attributed to MIT's 6.824 distributed systems course. The changes I have made are:
1. Re-structured the `raft` package to work with my `$GOPATH`.
2. Factored all of the essential code for lab 2 into this repository.
3. Created a `Makefile` to make running test commands easier to remember.
3. Filled in all below parts of this lab with my own code -- _not_ on the `master` branch.

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

**Task**

Implement leader election and heartbeats(`AppendEntries RPCs with no log entries). The goal for Part 2A is for a single leader to be elected, for the leader to remain the leader if there are no failures, and for a new leader to take over if the old leader fails or if packets to/from the old leader are lost.

✅ To test your code, run:
```sh
$ make test_a
# or: go test -run 2A ./pkg/raft
```

💡A good way to debug your code is to insert print statements when a peer sends or receives a message, and collect the output in a file with `go test -run 2A ./pkg/raft > out`. Then, by studying the trace messages in the `out` file, you can identify where your implementation deviates from the desired protocol. You might find `DPrintf` in `util.go` useful to turn printing on and off as you debug different problems.

**Figure**

[Insert Figure Here]


**Hints:**
* Add any state you need to the `Raft` struct in `raft.go`. You'll also need to define a struct to hold information about each log entry. Your code should follow Figure 2 in the paper as closely as possible.
* Fill in the `RequestVoteArgs` and the `RequestVoteReply` structs. Modify `Make()` to create a background goroutine that will kick off leader election periodically by sending out `RequestVote` RPCs when it hasn't head from another peer for a while. This way a peer will learn who is the leader, if there is already a leader, or become the leader itself. Implement the `RequestVote()` RPC handler so that servers will vote for one another.
* To implement heartbeats, define an `AppendEntries` RPC struct (though you may not need all the arguments yet), and have the leader send them out periodically. Write an `AppendEntries` RPC handler method that resets the election timeout so that other servers don't step forward as leaders when one has already been elected. 
* The tester requires that the leader send heartbeat RPCs no more than 10 times per second.
* The tester requires your Raft to elect a new leader within 5 seconds of the failure of the old leader (if a majority of peers can still communicate). Remember, however, that leader election may require multiple rounds in case of a split vote. You must pick election timeouts (and thus heartheat intervals) that are short enough that it's very likely that an _election will complete in < 5 seconds even if requires multiple rounds_.
* The paper's Section 5.2 mentions election timeouts in the range of 150 to 300 ms; however, since the tester limits you to 10 heartbeats per second, you will have to use a larger election timeout than the paper.
* You may find Go's [rand](https://golang.org/pkg/math/rand/) useful.
* You'll need to write code that takes actions periodically or after delays in time. The easiest way to do this is to create a goroutine with a loop that calls `time.Sleep()`. The hard way is to use Go's `time.Timer` or `time.Ticker`, which are difficult to use correctly.
* If you are puzzled about locking, you may find this [advice](https://pdos.csail.mit.edu/6.824/labs/raft-locking.txt) helpful.
* If your code has trouble passing the tests, read the paper's Figure 2 again; the full logic for leader election is spread over multiple parts of the figure.
* Go RPC sends only struct fields whose names start with capital letters. Sub-structures must also have capitalized field names (e.g. fields of log records in an array). The `internal/labgob` package will warn you about this; don't ignore it.
* You should check your code with `go test -race`, and fix any races it reports.

Be sure that you pass the 2A tests, seeing something like this:

```sh
$ make test_a
Test (2A): initial election ...
  ... Passed --   2.5  3   30    0
Test (2A): election after network failure ...
  ... Passed --   4.5  3   78    0
PASS
ok      raft    7.016s
$
```

Each "Passed" line contains the following 4 numbers:
* the time that the test took in seconds, 
* the number of Raft peers (3 or 5), 
* the number of RPCs sent during the test, and 
* the number of log entries that Raft reports were committed.

The grading script will fail your solution _if it takes more than 600 seconds for all tests, or if any individual test takes more than 120 seconds.
