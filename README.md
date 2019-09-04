# Replicator Synchronous Replication Demo

This demo proves the principle of synchronous replication using the interceptor here:

https://github.com/thomaskwscott/SynchronousReplicatorPoc

## Running the demo

Start cp-demo in the normal fashion, once started start 2 shell sessions in the kafka1 container. For the purposes of this test we will use the, already replicating wikipedia.parsed topic (we disabled the source connector that feeds this so we can feed it manually).

1. In one shell session run a test producer that is configured with the interceptor:

```
java -cp /usr/bin/../share/java/kafka/*:/usr/bin/../share/java/confluent-support-metrics/*:/usr/share/java/confluent-support-metrics/* io.confluent.interceptors.ProducerTest
```

The source code (with configuration properties) for this can be found here: 

https://github.com/thomaskwscott/SynchronousReplicatorPoc/blob/master/src/main/java/io/confluent/interceptors/ProducerTest.java

2. This will produce 3 messages with output similar to the following:

```
About to send record 0
Sent record 0
About to send record 1
Sent record 1
About to send record 2
Sent record 2
Sent 3 records in 179.0 seconds (179454 milliseconds), total of 0.016759777 events per second
```

3. In the other session monitor the Replicator consumer (run this repeatedly) whilst the test producer is producing:

```
kafka-consumer-groups --bootstrap-server localhost:10091 --group connect-replicator --describe
```

Please ignore "Error: Consumer group 'connect-replicator' does not exist.". This just means Replicator has not committed any offsets yet.

### Expected Behaviour

After seeing the "About to send..." message from the producer you will see the Replicator consumer group lage by 1 message. This means that the message has been written to the source cluster but not yet replicated. 

Once Replicator catches up and the lag reduces to zero you will see the "Sent record ..." message on the producer application. This indicates that the producer was blocked until replication completed.

### Big Caveat

This project intends to prove the concept only and performance is terrible!

### Next Steps

Right now replicator only commits offsets at intervals and so lag is extremely high. If replicator was to commit offsets as fast as it could lag would come right down.

