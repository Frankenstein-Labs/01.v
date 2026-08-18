# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::CiCdMenu, feature_category: :navigation do
  let(:project) { build_stubbed(:project) }
  let(:user) { project.first_owner }
  let(:context) do
    Sidebars::Projects::Context.new(
      current_user: user, container: project, current_ref: 'master', can_view_pipeline_editor: true
    )
  end

  describe 'Test cases Feature Library metadata' do
    subject(:test_cases_item) do
      described_class.new(context).renderable_items.find { |e| e.item_id == :test_cases }
    end

    context 'when quality_management is licensed' do
      before do
        stub_licensed_features(quality_management: true)
      end

      it 'tags the item as an Ultimate feature', :aggregate_failures do
        serialized = test_cases_item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:ultimate)
        expect(serialized).to include(:description, :library_icon)
      end

      context 'when user cannot read issues' do
        let(:user) { nil }

        it 'does not render the item' do
          is_expected.to be_nil
        end
      end
    end

    context 'when quality_management is not licensed' do
      before do
        stub_licensed_features(quality_management: false)
      end

      it 'does not render the item' do
        is_expected.to be_nil
      end
    end
  end
end
