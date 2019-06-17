# Kafka Log Appender Demo

This demo is a proof of concept showing a custom developed Log4J appender logging Zookeeper and Broker log messages back into Kafka (please note that broker 2 is not instrumented for compa). 

## Usage

Everything is pre configured so just start in the usual cp-demo way. You can verify the appender as follows:

1. Verify configs:

```
kafka-console-consumer --bootstrap-server localhost:10091 --topic _confluent-configs --from-beginning
```

2. Verify logs 

```
kafka-console-consumer --bootstrap-server localhost:10091 --topic _confluent-logs 
```

## Caveats

This is a basic proof of concept and missing most features. For a full list of these see the one pager. The following are the obvious ones:

1. It doesn't create the logging topics - in this demo auto topic create is enabled. In the final version it will manage topic creation
2. There is no retention configured - Don't run this for long as it will fill disk
3. Config isn't used to configure the appender - right now we just harvest config, in later versions we plan to use this config to automatically configure the appender.