# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/saml_reload_modal', feature_category: :system_access do
  let(:partial) { 'shared/saml_reload_modal' }

  let_it_be(:saml_provider) { create_default(:saml_provider) }
  let_it_be(:root_group) { saml_provider.group }
  let_it_be(:nested_group) { create_default(:group, :private, parent: root_group) }
  let_it_be(:project) { create_default(:project, :private, group: root_group) }
  let_it_be(:user) { create_default(:user, developer_of: root_group) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  context 'with root group' do
    it 'renders div with correct ID and data attribute' do
      render partial, group_or_project: root_group, current_user: user

      expect(rendered).to have_selector('#js-saml-reload[data-saml-provider-id]')
    end
  end

  context 'with subgroup' do
    it 'renders div with correct ID and data attribute' do
      render partial, group_or_project: nested_group, current_user: user

      expect(rendered).to have_selector('#js-saml-reload[data-saml-provider-id]')
    end
  end

  context 'with project' do
    it 'renders div with correct ID and data attribute' do
      render partial, group_or_project: project, current_user: user

      expect(rendered).to have_selector('#js-saml-reload[data-saml-provider-id]')
    end
  end
end
