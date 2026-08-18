# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Features::RepoFilterSearch, feature_category: :global_search do
  it_behaves_like 'zoekt feature', feature: :repo_filter_search
end
