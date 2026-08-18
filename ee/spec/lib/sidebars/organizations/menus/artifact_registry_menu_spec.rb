# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Organizations::Menus::ArtifactRegistryMenu, feature_category: :artifact_registry do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- read_artifact_registry policy checks organization membership, which requires persisted records
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  let(:context) { Sidebars::Context.new(current_user: user, container: organization) }

  subject(:menu) { described_class.new(context) }

  describe '#render?' do
    subject { menu.render? }

    context 'when the feature flag is enabled and the user can read the artifact registry' do
      before do
        create(:organization_user, organization: organization, user: user)
      end

      it { is_expected.to be true }

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(artifact_registry_ui: false)
        end

        it { is_expected.to be false }
      end
    end

    context 'when the user cannot read the artifact registry' do
      it { is_expected.to be false }
    end

    context 'when there is no current user' do
      let(:context) { Sidebars::Context.new(current_user: nil, container: organization) }

      it { is_expected.to be false }
    end
  end

  describe '#title' do
    it 'is the Artifact registry navigation area title' do
      expect(menu.title).to eq(s_('ArtifactRegistry|Artifact registry'))
    end
  end

  describe '#sprite_icon' do
    it 'has an icon' do
      expect(menu.sprite_icon).to be_present
    end
  end

  describe '#pick_into_super_sidebar?' do
    it { expect(menu.pick_into_super_sidebar?).to be true }
  end

  describe 'the Repositories menu item' do
    before do
      create(:organization_user, organization: organization, user: user)
    end

    it 'is the only item and links to the slug-scoped repositories path', :aggregate_failures do
      expect(menu.renderable_items.size).to eq(1)

      item = menu.renderable_items.first

      expect(item.title).to eq('Repositories')
      expect(item.link).to eq(
        "/o/#{organization.path}/-/artifact_registry/#{Organizations::ArtifactRegistry::STUB_SLUG}/repositories"
      )
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
