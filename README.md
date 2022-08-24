# Integrating Spring Boot Application with a Local Docker Cassandra Instance

## Learning Goals

- Experience setting up Spring Data connections for Cassandra
- Experience running a local Dev Cassandra Docker instance

## Instructions

In this lab, we will be implementing a simple Spring Boot Data model using our new local Cassandra instance. This will be very similar
to what we had done with Postgres. This is one of the large benefits of using the abstraction provided by Spring Boot Data, and can also
be applied to many other Database systems.

## Setting up the Spring Data Cassandra connections

Again, we will start with the simple baseling Spring Boot [application](https://spring.io/guides/gs/rest-service/). Pull this application
down again, and start up a new IntelliJ project.

``` text
git clone https://github.com/spring-guides/gs-rest-service.git
cd gs-rest-service
git checkout 5cbc686 # To rollback to Spring Boot 2.6.x
```

After launching the application, you should see the following again.

``` text
curl http://localhost:8080/greeting
```
``` shell
{"id":1,"content":"Hello, World!"}%
```
``` text
curl http://localhost:8080/greeting
```
``` shell
{"id":2,"content":"Hello, World!"}%
```

We will go ahead and implement the counter again as a persisted Java Object, this time using Cassandra though. We'll need to add this
new dependency into the `pom.xml` file.
There are actually two different drivers for Cassandra that can be used. We are using the Spring Data on in this case, but there is also
a native Cassandra Driver if more performance is needed. It will not work as smoothly with Spring Data however, so there are trade offs.

``` text
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-cassandra</artifactId>
  </dependency>
```


We are going to start with a minimal viable counter. Let us create a new class under `src/main/java/com/example/restservice/Counter.java`,
and its database interface under `src/main/java/com/example/restservice/CounterRepository.java`. Note that we are using Cassandra specific
annotations now for setting up the Data Objects.

``` java
package com.example.restservice;

import org.springframework.data.cassandra.core.mapping.PrimaryKey;
import org.springframework.data.cassandra.core.mapping.Table;

@Table
public class Counter {

    @PrimaryKey
    private String name;

    private Long count;

    public Counter(Long count, String name) {
        this.count = count;
        this.name = name;
    }

    public Long incrementAndGet() {
        this.count += 1;
        return count;
    }
}
```

``` java
package com.example.restservice;

import org.springframework.data.repository.CrudRepository;

public interface CounterRepository extends CrudRepository<Counter, String> {}
```

And now make a few modifications to `src/main/java/com/example/restservice/GreetingController.java` to implement the new persistent
endpoint.

``` java
...
import org.springframework.beans.factory.annotation.Autowired;
...

    @Autowired
    private CounterRepository counterRepository;
    
    @GetMapping("/persistent_greeting")
    public Greeting persistentGreeting(@RequestParam(value = "name", defaultValue = "World") String name) {
        Counter persistentCounter = counterRepository.findById("spring_counter").orElseGet(() ->
                new Counter(0L, "spring_counter"));
        Long persistentCounterValue = persistentCounter.incrementAndGet();
        counterRepository.save(persistentCounter);
        return new Greeting(persistentCounterValue, String.format(template, name));
    }
```

Let us take a look at the application properties now. We'll have to create this new file in `src/main/resources/application.properties`

``` text
spring.data.cassandra.schema-action=CREATE_IF_NOT_EXISTS
spring.data.cassandra.request.timeout=10s
spring.data.cassandra.connection.connect-timeout=10s
spring.data.cassandra.connection.init-query-timeout=10s

spring.data.cassandra.local-datacenter=datacenter1
spring.data.cassandra.keyspace-name=spring_cassandra

spring.data.cassandra.contact-points = 127.0.0.1:9042

spring.data.cassandra.username=cassandra
spring.data.cassandra.password=cassandra
```

And in this case, we need to manually instantiate the Keyspace on the DB end.

``` text
docker exec -it cassandra-lab /bin/bash
root@a03e783ff4fe:/# cqlsh
```
``` shell
Connected to Test Cluster at 127.0.0.1:9042
[cqlsh 6.0.0 | Cassandra 4.0.4 | CQL spec 3.4.5 | Native protocol v5]
Use HELP for help.
```
``` text
cqlsh> CREATE KEYSPACE IF NOT EXISTS spring_cassandra WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : '1' };
```

You should be able to rerun the application now, and see that the new endpoint persists if you restart the application

``` text
curl "http://localhost:8080/greeting"
```
``` shell
{"id":1,"content":"Hello, World!"}%
```
``` text
curl "http://localhost:8080/greeting"
```
``` shell
{"id":2,"content":"Hello, World!"}%
```
``` text
curl "http://localhost:8080/persistent_greeting"
```
``` shell
{"id":1,"content":"Hello, World!"}%
```
``` text
curl "http://localhost:8080/persistent_greeting"
```
``` shell
{"id":2,"content":"Hello, World!"}%
```
``` text
# Restart application
...
curl "http://localhost:8080/greeting"
```
``` shell
{"id":1,"content":"Hello, World!"}%
```
``` text
curl "http://localhost:8080/persistent_greeting"
```
``` shell
{"id":3,"content":"Hello, World!"}%
```

Go back and compare the database implementation here with what was done in the Postgres lab, you should see that they
are more alike than different when being used through Spring Data.


## Testing

The following command will run the tests to validate that this environment was setup correctly. A screenshot of the successful tests can be uploaded as a submission.

``` text
docker run --network labnetwork -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/test:/test inspec-lab exec docker.rb
```
``` shell
Profile:   tests from docker.rb (tests from docker.rb)
Version:   (not specified)
Target:    local://
Target ID: 

  ✔  Cassandra Running: Cassandra Docker instance is running
     ✔  #<Inspec::Resources::DockerImageFilter:0x00005591c4982398> with repository == "cassandra" tag == "4.0.4" is expected to exist
     ✔  #<Inspec::Resources::DockerContainerFilter:0x00005591c47c44c0> with names == "cassandra-lab" image == "cassandra:4.0.4" ports =~ /0.0.0.0:9042/ status is expected to match [/Up/]
     ✔  Cassandra query: SELECT cluster_name FROM system.local output is expected to match /Test Cluster/
  ✔  Cassandra Spring Keyspace: spring_cassandra Keyspace exists
     ✔  Cassandra query: DESCRIBE KEYSPACE spring_cassandra output is expected not to match /not found/
  ✔  Cassandra Counter Table: Counter Table exists
     ✔  Cassandra query: SELECT name FROM spring_cassandra.counter output is expected to match /spring_counter/


Profile Summary: 3 successful controls, 0 control failures, 0 controls skipped
Test Summary: 5 successful, 0 failures, 0 skipped
```
