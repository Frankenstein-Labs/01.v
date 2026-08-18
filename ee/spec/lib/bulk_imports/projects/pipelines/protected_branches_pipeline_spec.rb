# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::ProtectedBranchesPipeline, feature_category: :importers do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:bulk_import, freeze: false) { create(:bulk_import, user: user) }
  let_it_be(:entity, freeze: false) { create(:bulk_import_entity, :project_entity, project: project, bulk_import: bulk_import) }
  let_it_be(:tracker, freeze: false) { create(:bulk_import_tracker, entity: entity) }
  let_it_be(:context, freeze: false) { BulkImports::Pipeline::Context.new(tracker) }
  let_it_be(:protected_branch, freeze: false) do
    {
      'name' => 'main',
      'created_at' => '2016-06-14T15:02:47.967Z',
      'updated_at' => '2016-06-14T15:02:47.967Z',
      'unprotect_access_levels' => [{ 'access_level' => Gitlab::Access::MAINTAINER }]
    }
  end

  subject(:pipeline) { described_class.new(context) }

  describe '#run' do
    it 'imports protected branch information with unprotect access levels' do
      allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
        allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [protected_branch, 0]))
      end

      allow(pipeline).to receive(:set_source_objects_counter)

      pipeline.run

      imported_protected_branch = project.protected_branches.last
      unprotect_access_level = imported_protected_branch.unprotect_access_levels.first

      expect(unprotect_access_level.access_level).to eq(protected_branch['unprotect_access_levels'].first['access_level'])
    end
  end
end
