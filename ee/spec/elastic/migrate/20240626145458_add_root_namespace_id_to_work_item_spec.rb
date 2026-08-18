# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240626145458_add_root_namespace_id_to_work_item.rb')

RSpec.describe AddRootNamespaceIdToWorkItem, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240626145458
end
