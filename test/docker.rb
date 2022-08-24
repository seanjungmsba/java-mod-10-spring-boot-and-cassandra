control 'Cassandra Running' do
  impact 'critical'
  title 'Cassandra Docker instance is running'
  desc 'A Cassandra instance is running and accessible'

  describe docker.images.where { repository == 'cassandra' && tag == '4.0.4' } do
    it { should exist }
  end
  describe docker.containers.where { names == 'cassandra-lab' && image == 'cassandra:4.0.4' && ports =~ /0.0.0.0:9042/  } do
    its('status') { should match [/Up/] }
  end
  cql = cassandradb_session(user: 'cassandra', password: 'cassandra', host: 'cassandra-lab', port: 9042)
  describe cql.query("SELECT cluster_name FROM system.local") do
    its('output') { should match /Test Cluster/ }
  end
end

control 'Cassandra Spring Keyspace' do
  impact 'critical'
  title 'spring_cassandra Keyspace exists'
  desc 'The spring_cassandra keyspace exists on the Cassandra node'

  cql = cassandradb_session(user: 'cassandra', password: 'cassandra', host: 'cassandra-lab', port: 9042)
  describe cql.query("DESCRIBE KEYSPACE spring_cassandra") do
    its('output') { should_not match /not found/ }
  end
end

control 'Cassandra Counter Table' do
  impact 'critical'
  title 'Counter Table exists'
  desc 'The counter table exists in the spring_cassandra keyspace'

  cql = cassandradb_session(user: 'cassandra', password: 'cassandra', host: 'cassandra-lab', port: 9042)
  describe cql.query("SELECT name FROM spring_cassandra.counter") do
    its('output') { should match /spring_counter/ }
  end
end

