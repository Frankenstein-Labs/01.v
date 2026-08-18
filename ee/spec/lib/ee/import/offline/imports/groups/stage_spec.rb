# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Offline::Imports::Groups::Stage, feature_category: :importers do
  let(:bulk_import) { build(:bulk_import, source_enterprise: source_enterprise) }
  let(:entity) { build(:bulk_import_entity, bulk_import: bulk_import) }
  let(:source_enterprise) { true }
  let(:expected_pipelines) do
    [
      {
        stage: 1,
        pipeline: BulkImports::Groups::Pipelines::IterationsCadencesPipeline
      },
      { stage: 2, pipeline: BulkImports::Groups::Pipelines::EpicsPipeline },
      { stage: 2, pipeline: BulkImports::Groups::Pipelines::EpicBoardsPipeline }
    ]
  end

  subject(:stage) { described_class.new(entity) }

  describe '#pipelines' do
    it 'includes reusable EE file-based group pipelines' do
      expect(stage.pipelines).to include(*expected_pipelines)
    end

    context 'when source is not enterprise' do
      let(:source_enterprise) { false }

      it 'does not include reusable EE file-based group pipelines' do
        expect(stage.pipelines).not_to include(*expected_pipelines)
      end
    end
  end
end
