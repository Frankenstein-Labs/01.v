# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::SbomOccurrenceRefIndexHelper, feature_category: :dependency_management do
  using RSpec::Parameterized::TableSyntax

  before do
    allow(Gitlab::CurrentSettings).to receive_messages(
      elasticsearch_indexing?: indexing,
      elasticsearch_search?: searching
    )
    allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
      .with(:create_sbom_occurrence_refs_index).and_return(migration_finished)
  end

  describe '.indexing_allowed?' do
    where(:indexing, :migration_finished, :expected) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      let(:searching) { true }

      it { expect(described_class.indexing_allowed?).to be(expected) }
    end
  end

  describe '.advanced_dependency_management_allowed?' do
    where(:indexing, :migration_finished, :searching, :expected) do
      true  | true  | true  | true
      true  | true  | false | false
      true  | false | true  | false
      true  | false | false | false
      false | true  | true  | false
      false | false | true  | false
    end

    with_them do
      it { expect(described_class.advanced_dependency_management_allowed?).to be(expected) }
    end
  end
end
