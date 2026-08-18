# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Features::TraversalIdSearch, feature_category: :global_search do
  it_behaves_like 'zoekt feature', feature: :traversal_id_search
end
