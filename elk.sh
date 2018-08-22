#/bin/bash
java -version > /dev/null 2>&1
if [ `echo $?` -ne 0 ]
then
        sudo yum install java -y
fi
echo "Installing Elasticsearch"
echo '''[elasticsearch-2.x]
name=Elasticsearch repository for 2.x packages
baseurl=http://packages.elastic.co/elasticsearch/2.x/centos
gpgcheck=1
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
''' | sudo tee /etc/yum.repos.d/elasticsearch.repo
sudo yum -y install elasticsearch
sudo sed -i 's/# network.host: 192.168.0.1/network.host: localhost/g' /etc/elasticsearch/elasticsearch.yml
sudo service elasticsearch start
sudo service elasticsearch status
echo "Installing Kibana"
echo ''' [kibana-4.4]
name=Kibana repository for 4.4.x packages
baseurl=http://packages.elastic.co/kibana/4.4/centos
gpgcheck=1
gpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch
enabled=1
''' | sudo tee /etc/yum.repos.d/kibana.repo
sudo yum -y install kibana
sudo sed -i 's/# server.host: "0.0.0.0"/server.host: "0.0.0.0"/g' /opt/kibana/config/kibana.yml
sudo service kibana start
sudo service kibana status
echo "Installing Logstash"
echo '''[logstash-2.2]
name=logstash repository for 2.2 packages
baseurl=http://packages.elasticsearch.org/logstash/2.2/centos
gpgcheck=1
gpgkey=http://packages.elasticsearch.org/GPG-KEY-elasticsearch
enabled=1
''' | sudo tee /etc/yum.repos.d/logstash.repo
sudo yum -y install logstash
echo '''input {
  beats {
    port => 5044
  }
}
''' | sudo tee /etc/logstash/conf.d/02-beats-input.conf
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
''' | sudo tee /etc/logstash/conf.d/10-syslog-filter.conf
echo '''output {
  elasticsearch {
    hosts => ["localhost:9200"]
    sniffing => true
    manage_template => false
    index => "om_elk%{[@metadata][beat]}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}
''' | sudo tee /etc/logstash/conf.d/30-elasticsearch-output.conf
sudo service logstash start
sudo service logstash status
sudo rpm --import http://packages.elastic.co/GPG-KEY-elasticsearch
echo '''[beats]
name=Elastic Beats Repository
baseurl=https://packages.elastic.co/beats/yum/el/$basearch
enabled=1
gpgkey=https://packages.elastic.co/GPG-KEY-elasticsearch
gpgcheck=1
''' | sudo tee /etc/yum.repos.d/elastic-beats.repo
sudo yum -y install filebeat
sudo sed -i 's/#document_type: log/document_type: syslog/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/\/var\/log\/\*.log/var\/log\/messages/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/#logstash:/logstash:/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/#hosts: \[\"localhost:5044\"\]/hosts: \[\"localhost:5044\"\]/g' /etc/filebeat/filebeat.yml
sudo sed -i 's/#bulk_max_size: 2048/bulk_max_size: 1024/g' /etc/filebeat/filebeat.yml
sudo service filebeat start
sudo service filebeat status
