# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../elastic/migrate/20260508203810_mark_legacy_migrations_index_read_only'

RSpec.describe MarkLegacyMigrationsIndexReadOnly, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20260508203810
end
