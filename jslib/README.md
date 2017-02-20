
This deliberately exists outside of /app/assets/javascripts to allow
browserify/npm to find and use these libraries while also avoiding
Rails picking them up in its asset pipeline.
