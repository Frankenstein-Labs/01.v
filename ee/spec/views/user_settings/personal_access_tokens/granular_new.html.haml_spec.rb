# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'user_settings/personal_access_tokens/granular_new.html.haml', feature_category: :system_access do
  let_it_be(:user) { build(:user) }
  let_it_be(:groups_requiring_reauth) { build_list(:group, 2) }

  before do
    allow(view).to receive(:current_user) { user }
    allow(view).to receive_messages(user_groups_requiring_reauth: groups_requiring_reauth)
  end

  it 'renders a group SAML re-authentication banner' do
    render

    expect(rendered).to have_text(s_('GroupSAML|Group SAML single sign-on session expired'))
    groups_requiring_reauth.each do |group|
      expect(rendered).to have_text(format(s_('GroupSAML|Re-authenticate %{group}'), group: group.path))
    end
  end

  context 'when no groups require reauth' do
    let(:groups_requiring_reauth) { [] }

    it 'does not render the saml reauth notice' do
      render

      expect(rendered).not_to have_selector('.js-saml-reauth-notice')
    end
  end
end
