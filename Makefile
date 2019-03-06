.PHONY: *

test: 
		go test ./pkg/raft

test_a:
		go test -run 2A ./pkg/raft