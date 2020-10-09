# Solr configuration for running specs

TODO: merge this documentation with main README 

## Create and run container image:

Do this from the project root directory:
```
docker run -d -p 9983:8983 --name franklin_solr -v $PWD/solr/conf:/opt/solr/server/solr/configsets quay.io/upennlibraries/upenn_solr:7.7.0 /opt/solr/bin/solr start -c -f -m 2g -p 8983
```

You can then reach the Solr UI at [`localhost:9983`](localhost:9983)

## Create solr collection(s)

### For `test` environment

```
docker exec -it franklin_solr bash -c 'bin/solr create_collection -c franklin-test -d franklin'
```

### For `development` environment, if you like

```
docker exec -it franklin_solr bash -c 'bin/solr create_collection -c franklin-dev -d franklin'
```

## Load some sample data

## Misc

To stop the container: `docker stop franklin_solr`
To delete the container: `docker rm franklin_solr`