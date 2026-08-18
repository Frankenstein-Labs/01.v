# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Common::Pipelines::WikiPipeline, feature_category: :importers do
  describe '#run' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:parent) { create(:group) }
    let_it_be_with_reload(:bulk_import) { create(:bulk_import, user: user) }

    let_it_be_with_reload(:entity) do
      create(
        :bulk_import_entity,
        :group_entity,
        bulk_import: bulk_import,
        source_full_path: 'source/full/path',
        destination_slug: 'My-Destination-Wiki',
        destination_namespace: parent.full_path,
        group: parent
      )
    end

    it_behaves_like 'wiki pipeline imports a wiki for an entity'
  end
end
