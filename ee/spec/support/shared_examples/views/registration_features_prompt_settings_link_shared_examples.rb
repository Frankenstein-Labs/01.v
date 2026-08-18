# frozen_string_literal: true

RSpec.shared_examples 'renders registration features settings link' do
  let_it_be(:admin, freeze: false) { create(:admin) }
  let_it_be(:user, freeze: false) { create(:user) }

  context 'as regular user' do
    before do
      allow(view).to receive(:current_user) { user }
      allow(view).to receive(:can?).with(user, :admin_group, anything).and_return(false)
    end

    it 'does not render settings link', :aggregate_failures do
      expect(rendered).not_to have_link(s_('RegistrationFeatures|Enable Service Ping and register for this feature.'))
    end
  end

  context 'as admin', :enable_admin_mode do
    before do
      allow(view).to receive(:current_user) { admin }
      allow(view).to receive(:can?).with(admin, :admin_group, anything).and_return(true)
    end

    it 'renders settings link', :aggregate_failures do
      render

      expect(rendered).to have_link(s_('RegistrationFeatures|Enable Service Ping and register for this feature.'))
    end
  end
end
