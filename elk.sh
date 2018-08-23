#/bin/bash
yum update
java -version > /dev/null 2>&1
if [ `echo $?` -ne 0 ]
then
        yum install java -y
       sleep 20
fi
echo "Installing Elasticsearch"
echo '''[elasticsearch-2.x]
name=Elasticsearch repository for 2.x packages
baseurl=http://packages.elastic.co/elasticsearch/2.x/centos
gpgcheck=1
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
''' |  tee /etc/yum.repos.d/elasticsearch.repo
yum -y install elasticsearch
sleep 10
sed -i 's/# network.host: 192.168.0.1/network.host: localhost/g' /etc/elasticsearch/elasticsearch.yml
service elasticsearch start
service elasticsearch status
echo "Installing Kibana"
echo ''' [kibana-4.4]
name=Kibana repository for 4.4.x packages
baseurl=http://packages.elastic.co/kibana/4.4/centos
gpgcheck=1
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
''' |  tee /etc/yum.repos.d/kibana.repo
yum -y install kibana
sleep 10
sed -i 's/# server.host: "0.0.0.0"/server.host: "0.0.0.0"/g' /opt/kibana/config/kibana.yml
service kibana start
service kibana status
echo "Installing Logstash"
echo '''[logstash-2.2]
name=logstash repository for 2.2 packages
baseurl=http://packages.elasticsearch.org/logstash/2.2/centos
gpgcheck=1
gpgkey=http://packages.elasticsearch.org/GPG-KEY-elasticsearch
enabled=1
''' |  tee /etc/yum.repos.d/logstash.repo
yum -y install logstash
sleep 10
echo '''input {
 beats {
   port => 5044
 }
}
''' |  tee /etc/logstash/conf.d/02-beats-input.conf
echo '''filter {
 if [type] == "syslog" {
   grok {
     match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
     add_field => [ "received_at", "%{@timestamp}" ]
     add_field => [ "received_from", "%{host}" ]
   }
   syslog_pri { }
   date {
     match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
   }
 }
}
''' |  tee /etc/logstash/conf.d/10-syslog-filter.conf
echo '''output {
 elasticsearch {
   hosts => ["localhost:9200"]
   sniffing => true
   manage_template => false
   index => "om_elk%{[@metadata][beat]}-%{+YYYY.MM.dd}"
   document_type => "%{[@metadata][type]}"
 }
}
''' |  tee /etc/logstash/conf.d/30-elasticsearch-output.conf
service logstash start
service logstash status
rpm --import http://packages.elastic.co/GPG-KEY-elasticsearch
echo '''[beats]
name=Elastic Beats Repository
baseurl=https://packages.elastic.co/beats/yum/el/$basearch
enabled=1
gpgkey=https://packages.elastic.co/GPG-KEY-elasticsearch
gpgcheck=1
''' |  tee /etc/yum.repos.d/elastic-beats.repo
yum -y install filebeat
sleep 10
sed -i 's/#document_type: log/document_type: syslog/g' /etc/filebeat/filebeat.yml
sed -i 's/\/var\/log\/\*.log/var\/log\/messages/g' /etc/filebeat/filebeat.yml
sed -i 's/#logstash:/logstash:/g' /etc/filebeat/filebeat.yml
sed -i 's/#hosts: \[\"localhost:5044\"\]/hosts: \[\"localhost:5044\"\]/g' /etc/filebeat/filebeat.yml
sed -i 's/#bulk_max_size: 2048/bulk_max_size: 1024/g' /etc/filebeat/filebeat.yml
service filebeat start
service filebeat status
sleep 5
echo "Starting elasticsearch"
service elasticsearch restart
echo "Starting logstash"
service logstash restart
echo "Starting kibana"
service kibana restart
echo "Starting filebeat"
service filebeat restart
~                                  
