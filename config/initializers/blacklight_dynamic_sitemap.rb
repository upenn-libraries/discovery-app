config = BlacklightDynamicSitemap::Engine.config
config.hashed_id_field = 'hashed_id_si'
config.last_modified_field = 'last_update_isort'
config.format_last_modified = lambda { |raw_last_modified|
  Time.at(raw_last_modified).strftime('%Y-%m-%dT%H:%M:%S%:z')
}
config.modify_index_params = lambda { |params|
  params[:fq] = '{!term f=record_source_f v=Penn}'
  return params
}
config.modify_show_params = lambda { |id, params|
  params[:fq] << '{!term f=record_source_f v=Penn}'
  params[:sort] = 'last_update_isort desc'
  params[:routingHash] = id.hex
  return params
}
