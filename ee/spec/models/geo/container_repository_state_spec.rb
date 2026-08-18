# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ContainerRepositoryState, :geo, feature_category: :geo_replication do
  it { is_expected.to belong_to(:container_repository).inverse_of(:container_repository_state) }
  it { is_expected.to validate_presence_of(:verification_state) }
  it { is_expected.to validate_presence_of(:container_repository) }
end
