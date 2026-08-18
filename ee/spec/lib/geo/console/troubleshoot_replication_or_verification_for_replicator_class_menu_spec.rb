# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::TroubleshootReplicationOrVerificationForReplicatorClassMenu,
  feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:menu) do
    described_class.new(
      replicator_class: Geo::LfsObjectReplicator,
      referer: Geo::Console::Exit.new,
      input_stream: input_stream,
      output_stream: output_stream)
  end

  let(:input_stream) { StringIO.new("1\n") }
  let(:output_stream) { StringIO.new }

  it_behaves_like "a Geo console multiple choice menu"

  describe '#choices' do
    let_it_be(:secondary_node, freeze: true) { create(:geo_node, name: "Tokyo") }

    context 'when on a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'includes sync and verification failure actions' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).to include(Geo::Console::ShowSyncFailuresForReplicatorClassAction)
        expect(choice_classes).to include(Geo::Console::ShowVerificationFailuresForReplicatorClassAction)
      end
    end

    context 'when on an org migration target' do
      before do
        stub_org_migration_target_cell(secondary_node)
      end

      it 'includes sync and verification failure actions' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).to include(Geo::Console::ShowSyncFailuresForReplicatorClassAction)
        expect(choice_classes).to include(Geo::Console::ShowVerificationFailuresForReplicatorClassAction)
      end
    end

    context 'when on a primary' do
      let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }

      before do
        stub_current_geo_node(primary_node)
      end

      it 'includes primary checksum failures action' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).to include(Geo::Console::ShowPrimaryChecksumFailuresForReplicatorClassAction)
      end

      it 'does not include sync and verification failure actions' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).not_to include(Geo::Console::ShowSyncFailuresForReplicatorClassAction)
        expect(choice_classes).not_to include(Geo::Console::ShowVerificationFailuresForReplicatorClassAction)
      end
    end
  end
end
