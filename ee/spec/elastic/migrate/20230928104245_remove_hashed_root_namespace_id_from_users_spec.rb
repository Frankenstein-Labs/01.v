# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230928104245_remove_hashed_root_namespace_id_from_users.rb')

RSpec.describe RemoveHashedRootNamespaceIdFromUsers, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230928104245
end
