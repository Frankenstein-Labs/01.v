# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240517092224_add_routing_to_issues.rb')

RSpec.describe AddRoutingToIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240517092224
end
