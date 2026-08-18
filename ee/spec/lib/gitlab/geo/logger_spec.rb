# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::Logger, feature_category: :geo_replication do
  describe 'log level' do
    let(:logger) { described_class.build }

    it 'defaults to debug' do
      expect(logger.level).to eq(0)
    end

    it 'returns value defined by GITLAB_LOG_LEVEL' do
      stub_env('GITLAB_LOG_LEVEL', 'error')

      expect(logger.level).to eq(3)
    end
  end
end
