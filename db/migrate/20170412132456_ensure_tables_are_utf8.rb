class EnsureTablesAreUtf8 < ActiveRecord::Migration
  def change

    adapter = connection.adapter_name.downcase

    if adapter.start_with?('mysql')
      # this ensures any new tables created after this migration are utf8
      execute "ALTER DATABASE `#{connection.current_database}` CHARACTER SET utf8;"

      # convert existing tables
      execute 'ALTER TABLE bookmarks CONVERT TO CHARACTER SET utf8;'
      execute 'ALTER TABLE searches CONVERT TO CHARACTER SET utf8;'
      execute 'ALTER TABLE users CONVERT TO CHARACTER SET utf8;'
      execute 'ALTER TABLE schema_migrations CONVERT TO CHARACTER SET utf8;'
    else
      puts 'skipping migration for non-MySQL database'
    end

  end
end
