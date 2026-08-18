# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Features::TopLevelQuery, feature_category: :global_search do
  it_behaves_like 'zoekt feature', feature: :top_level_query
end
