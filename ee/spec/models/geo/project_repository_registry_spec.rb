# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryRegistry, :geo, type: :model, feature_category: :geo_replication do
  context 'for project repository replication v1' do
    include_examples 'Geo::ProjectRepositoryRegistry'
  end
end
