# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentsFinder, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:other_project) { create(:project, namespace: group) }

  let_it_be(:component_1) { create_component("activerecord", project: project) }
  let_it_be(:component_2) { create_component("component-a", project: project) }
  let_it_be(:component_3) { create_component("component-b", project: project) }
  let_it_be(:component_4) { create_component("buuba", project: project) }
  let_it_be(:component_5) { create_component("activesupport", project: other_project) }

  let(:finder) { described_class.new(target, query) }

  describe '#execute' do
    before do
      stub_const("#{described_class}::COMPONENT_NAMES_LIMIT", 3)
    end

    subject(:find) { finder.execute }

    context 'when given a project' do
      let(:target) { project }

      context 'when given no query string' do
        let(:query) { nil }

        it "returns all names up to limit", :aggregate_failures do
          expect(find.length).to eq(3)
          expect(find).to eq([component_1, component_4, component_2])
        end
      end

      context 'when given a query string' do
        let(:query) { "active" }

        it "returns all matching names" do
          expect(find).to match_array([component_1])
        end
      end
    end

    context 'when given a group' do
      let(:target) { group }

      context 'when given no query string' do
        let(:query) { nil }

        it "returns all names up to limit", :aggregate_failures do
          expect(find.length).to eq(3)
          expect(find).to eq([component_1, component_5, component_4])
        end
      end

      context 'when given a query string' do
        let(:query) { "active" }

        it "returns all matching names" do
          expect(find).to match_array([component_1, component_5])
        end
      end
    end

    context 'with invalid target' do
      let(:target) { Issue.new }
      let(:query) { nil }

      it 'raises an ArgumentError' do
        expect { find }.to raise_error(ArgumentError, "can't find components for Issue")
      end
    end
  end

  def create_component(name, project:)
    create(:sbom_component, name: name).tap do |component|
      create(:sbom_occurrence, component: component, project: project)
    end
  end
end
