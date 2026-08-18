# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Organizations::Menus::SettingsMenu, feature_category: :navigation do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:member) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  let(:user) { member }
  let(:context) { Sidebars::Context.new(current_user: user, container: organization) }

  subject(:artifact_registry_item) do
    described_class.new(context).renderable_items
      .find { |item| item.item_id == :organization_settings_artifact_registry }
  end

  before_all do
    create(:organization_user, organization: organization, user: member)
  end

  describe 'the Artifact registry settings item' do
    context 'when the feature flag is enabled and the user can read the registry' do
      it 'inserts the item linking to the organization settings artifact registry path', :aggregate_failures do
        expect(artifact_registry_item).to be_present
        expect(artifact_registry_item.link)
          .to eq(Gitlab::Routing.url_helpers.artifact_registry_settings_organization_path(organization))
      end
    end

    context 'when the artifact_registry_ui feature flag is disabled' do
      before do
        stub_feature_flags(artifact_registry_ui: false)
      end

      it 'does not insert the item' do
        expect(artifact_registry_item).to be_nil
      end
    end

    context 'when the user cannot read the registry' do
      let(:user) { non_member }

      it 'does not insert the item' do
        expect(artifact_registry_item).to be_nil
      end
    end
  end
end
