# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Offline::Imports::Projects::Stage, feature_category: :importers do
  let(:bulk_import) { build(:bulk_import, source_enterprise: source_enterprise) }
  let(:entity) { build(:bulk_import_entity, :project_entity, bulk_import: bulk_import) }
  let(:source_enterprise) { true }
  let(:expected_pipelines) do
    [
      { stage: 4, pipeline: BulkImports::Projects::Pipelines::PushRulePipeline },
      {
        stage: 6,
        pipeline: BulkImports::Projects::Pipelines::VulnerabilitiesPipeline
      },
      {
        stage: 7,
        pipeline: Import::Offline::Common::Pipelines::UserContributionsPipeline
      },
      {
        stage: 8,
        pipeline: BulkImports::Common::Pipelines::EntityFinisher
      }
    ]
  end

  subject(:stage) { described_class.new(entity) }

  describe '#pipelines' do
    it 'includes reusable EE file-based project pipelines and runs finalization after them' do
      expect(stage.pipelines).to include(*expected_pipelines)
    end

    context 'when source is not enterprise' do
      let(:source_enterprise) { false }

      it 'does not include reusable EE file-based project pipelines' do
        expect(stage.pipelines).not_to include(*expected_pipelines)
      end
    end
  end
end
