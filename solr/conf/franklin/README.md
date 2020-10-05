# Solr configuration for running specs

Create and run container image:

```
docker run -d -p 8983:8983 -v /home/mk/Projects/discovery-app/solr/conf:/opt/solr/server/solr/configsets quay.io/upennlibraries/upenn_solr:7.7.0 /opt/solr/bin/solr start -f -m 2g -p 8983
```

Create solr core

```
docker exec -it {container_name} bash "bin/solr create_core -c franklin_test -d franklin"
```

No dice.

Run `create_core.sh` from `docker exec`? Nope. Permission denied is likely.