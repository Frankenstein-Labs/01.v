# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::MainMenu, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:menu) { described_class.new(input_stream: input_stream, output_stream: output_stream) }
  let(:input_stream) { StringIO.new("1\n") }
  let(:output_stream) { StringIO.new }

  it_behaves_like "a Geo console multiple choice menu"

  describe '#choices' do
    let_it_be(:secondary_node, freeze: true) { create(:geo_node, name: "Tokyo") }

    context 'when on a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'includes site status actions' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).to include(Geo::Console::ShowCachedSecondarySiteStatusAction)
        expect(choice_classes).to include(Geo::Console::ShowUncachedSecondarySiteStatusAction)
      end
    end

    context 'when on an org migration target' do
      before do
        stub_org_migration_target_cell(secondary_node)
      end

      it 'includes site status actions' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).to include(Geo::Console::ShowCachedSecondarySiteStatusAction)
        expect(choice_classes).to include(Geo::Console::ShowUncachedSecondarySiteStatusAction)
      end
    end

    context 'when on a primary' do
      let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }

      before do
        stub_current_geo_node(primary_node)
      end

      it 'does not include site status actions' do
        choice_classes = menu.choices.compact.map(&:class)

        expect(choice_classes).not_to include(Geo::Console::ShowCachedSecondarySiteStatusAction)
      end
    end
  end
end
