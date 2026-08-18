# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Geo::PipelineRefs, feature_category: :geo_replication do
  let(:pipeline_refs) { ['foo'] }

  subject(:entity) { described_class.new(pipeline_refs: pipeline_refs).as_json }

  describe '#pipeline_refs' do
    it { expect(entity[:pipeline_refs]).to eq(pipeline_refs) }
  end
end
