# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Event, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to have_one(:geo_event_log) }
  end
end
