# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../elastic/migrate/20260420120000_migrate_migrations_index_to_alias'

RSpec.describe MigrateMigrationsIndexToAlias, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20260420120000
end
