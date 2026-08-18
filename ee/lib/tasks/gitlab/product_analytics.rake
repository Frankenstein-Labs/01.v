# frozen_string_literal: true

namespace :gitlab do
  namespace :product_analytics do
    desc 'GitLab | Analytics | Enable GitLab Product features on the specified group'
    task :setup, [:root_group_path] => :environment do |_, args|
      Gitlab::ProductAnalytics::Developments::Setup.new(args).execute
    end
  end
end
