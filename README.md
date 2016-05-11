# Production deployment of Blacklight

[Generic Blacklight Install](https://gitlab.library.upenn.edu/katherly/blacklight)

In the `blacklight-marc` gem, edit `lib/blacklight/marc/indexer/formats.rb` 
to temporarily disable 008 dependency near "Look in 008 to determine what 
type of Continuing Resource". Simply default to "Serial", i.e.: 
```
vals << 'Serial'
```
