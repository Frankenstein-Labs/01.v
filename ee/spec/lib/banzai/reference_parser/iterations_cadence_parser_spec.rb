# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::ReferenceParser::IterationsCadenceParser, feature_category: :markdown do
  include ReferenceParserHelpers

  def link_node(cadence_id)
    link = empty_html_link
    link['data-iterations-cadence'] = cadence_id.to_s
    link
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:parent_group) { create(:group, :private) }
  let_it_be(:group) { create(:group, :private, parent: parent_group) }
  let_it_be(:project) { create(:project, :private, group: group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:root_cadence) { create(:iterations_cadence, group: parent_group) }
  let_it_be(:another_cadence) { create(:iterations_cadence, group: create(:group, :private)) }

  let(:nodes) do
    [link_node(cadence.id), link_node(root_cadence.id), link_node(another_cadence.id)]
  end

  subject(:parser) { described_class.new(context) }

  shared_examples 'parses iterations cadence references' do
    describe '#nodes_visible_to_user' do
      before_all do
        group.add_developer(user)
      end

      context 'when the iterations feature is enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        it 'returns the nodes the user can read for valid iteration cadence nodes' do
          expect(parser.nodes_visible_to_user(user, nodes)).to match_array([nodes[0], nodes[1]])
        end

        it 'returns an empty array for nodes without required data-attributes' do
          expect(parser.nodes_visible_to_user(user, [empty_html_link])).to be_empty
        end
      end

      context 'when the iterations feature is disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'returns an empty array' do
          expect(parser.nodes_visible_to_user(user, nodes)).to be_empty
        end
      end
    end

    describe '#referenced_by' do
      describe 'when the link has `data-iterations-cadence` attribute' do
        context 'when using an existing iterations cadence ID' do
          it 'returns an Array of iterations cadences' do
            expect(parser.referenced_by([link_node(cadence.id)])).to eq([cadence])
          end
        end

        context 'when using an iterations cadence from parent group' do
          it 'returns an Array of iterations' do
            expect(parser.referenced_by([link_node(root_cadence.id)])).to eq([root_cadence])
          end
        end

        context 'when using a non-existing iterations cadence ID' do
          it 'returns an empty Array' do
            expect(parser.referenced_by([link_node(non_existing_record_id)])).to eq([])
          end
        end
      end
    end
  end

  context 'in project context' do
    let(:context) { Banzai::RenderContext.new(project, user) }

    it_behaves_like 'parses iterations cadence references'
  end

  context 'in group context' do
    let(:context) { Banzai::RenderContext.new(group, user) }

    it_behaves_like 'parses iterations cadence references'
  end
end
