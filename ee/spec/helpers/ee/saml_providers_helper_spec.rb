# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::SamlProvidersHelper, feature_category: :system_access do
  let_it_be_with_reload(:current_user) { create_default(:user, name: "John Doe", username: "john") }
  let_it_be_with_reload(:group) { create_default(:group, :public, name: "circuitverse") }

  describe "#saml_sign_in" do
    it "returns a hash with a sign in button text property, merged with SAML properties" do
      button_text = "Sign me in"
      redirect = "my_redirect"
      group_path = group.path
      group_name = group.full_name
      allow(helper)
        .to receive(:omniauth_authorize_path)
        .with(:user, :group_saml, { group_path: "circuitverse", redirect_to: redirect })
        .and_return("/users/auth/group_saml?group_path=circuitverse&redirect_to=#{redirect}")

      saml_data = helper.group_saml_sign_in(
        group: group,
        group_name: group_name,
        group_path: group_path,
        redirect: redirect,
        sign_in_button_text: button_text
      )

      expect(saml_data).to eq(
        {
          group_name: "circuitverse",
          group_url: "/circuitverse",
          rememberable: "true",
          saml_url: "/users/auth/group_saml?group_path=circuitverse&redirect_to=#{redirect}",
          sign_in_button_text: button_text
        })
    end
  end

  describe '#saml_membership_role_selector_data', :saas, feature_category: :permissions do
    let(:access_level) { Gitlab::Access::DEVELOPER }
    let(:member_role) { create_default(:member_role, namespace: group, base_access_level: access_level) }
    let!(:saml_provider) do
      create_default(:saml_provider, group: group, member_role: member_role, default_membership_role: access_level)
    end

    let(:expected_standard_role_data) do
      {
        standard_roles: group.access_level_roles,
        current_standard_role: access_level
      }
    end

    before_all do
      group.add_owner(current_user)
    end

    subject(:data) { helper.saml_membership_role_selector_data(group, current_user) }

    it 'returns a hash with the expected standard role data' do
      expect(data).to eq(expected_standard_role_data)
    end

    context 'when custom roles are enabled' do
      let(:expected_custom_role_data) do
        {
          custom_roles: [{
            member_role_id: member_role.id,
            name: member_role.name,
            base_access_level: member_role.base_access_level
          }],
          current_custom_role_id: member_role.id
        }
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'returns a hash with the expected standard and custom role data' do
        expect(data).to eq(expected_standard_role_data.merge(expected_custom_role_data))
      end
    end
  end

  describe '#saml_reload_data' do
    let_it_be(:saml_provider) { create_default(:saml_provider) }

    subject(:data) { helper.saml_reload_data(saml_provider) }

    it 'returns a hash with the expected data' do
      expect(data).to eq({
        saml_provider_id: saml_provider.id,
        saml_sessions_url: saml_user_settings_active_sessions_path(format: :json)
      })
    end
  end
end
