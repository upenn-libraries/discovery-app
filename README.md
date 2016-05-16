# Production deployment of Blacklight

[Generic Blacklight Install](https://gitlab.library.upenn.edu/katherly/blacklight)

* To get the jetty instance needed to power the application, run:
```bash
rake jetty:clean
```

If all is well, you should see output something like:
```bash
LTS-KL01:blacklight katherly$ rake jetty:clean
I, [2016-03-03T12:28:12.106876 #99629]  INFO -- : Downloading jetty at https://github.com/projectblacklight/blacklight-jetty/archive/v4.10.4.zip ...
I, [2016-03-03T12:28:26.932889 #99629]  INFO -- : Unpacking tmp/v4.10.4.zip...
```

And commit the change.

```bash
git add .gitignore
git commit -m "Added /jetty to .gitignore"
```

* Start jetty:
```bash
rake jetty:start
```

* Load test marc data into Solr:
```bash
rake solr:marc:index_test_data
```

This pulls 30 sample records from [the Blacklight-Data repository](https://github.com/projectblacklight/blacklight-data).

If the test data is successfully indexed, you should see output something like:
```bash
LTS-KL01:blacklight katherly$ rake solr:marc:index_test_data
2016-03-03T12:29:40-05:00  INFO    Traject::SolrJsonWriter writing to 'http://127.0.0.1:8983/solr/blacklight-core/update/json' in batches of 100 with 1 bg threads
2016-03-03T12:29:40-05:00  INFO    Indexer with 1 processing threads, reader: Traject::MarcReader and writer: Traject::SolrJsonWriter
2016-03-03T12:29:41-05:00  INFO Traject::SolrJsonWriter sending commit to solr at url http://127.0.0.1:8983/solr/blacklight-core/update/json...
2016-03-03T12:29:41-05:00  INFO finished Indexer#process: 30 records in 0.471 seconds; 63.8 records/second overall.
```

* Start the rails server:
```bash
rails s
```

* Open up [localhost:3000](localhost:3000) in a browser.  If everything went well, you should see the generic Blacklight homepage and have 30 faceted records to search.
