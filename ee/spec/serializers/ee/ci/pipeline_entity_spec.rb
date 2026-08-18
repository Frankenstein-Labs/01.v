# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineEntity, feature_category: :continuous_integration do
  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:user) }
  let(:pipeline) { build_stubbed(:ci_empty_pipeline, project: project) }
  let(:request) { double('request', current_user: user, project: project) }
  let(:entity) { described_class.represent(pipeline, request: request) }

  describe '#as_json' do
    subject(:entity_json) { entity.as_json }

    it 'contains flags' do
      expect(entity_json).to include :flags
      expect(entity_json[:flags]).to include :merge_train_pipeline
    end
  end
end
