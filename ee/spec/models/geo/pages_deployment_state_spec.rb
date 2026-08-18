# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PagesDeploymentState, :geo, feature_category: :geo_replication do
  it { is_expected.to belong_to(:pages_deployment).inverse_of(:pages_deployment_state) }
end
