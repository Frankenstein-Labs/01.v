# frozen_string_literal: true

RSpec.shared_examples 'Admin menu with custom ability' do |link:, title:, icon:, custom_ability:, separated: false|
  include_examples 'Admin menu', link: link, title: title, icon: icon, separated: separated

  describe '#render?' do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:role, freeze: false) { create(:member_role, custom_ability) }
    let_it_be(:user_member_role, freeze: false) { create(:user_member_role, member_role: role, user: user) }
    let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

    subject { described_class.new(context).render? }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when a custom ability allows access' do
      it { is_expected.to be true }
    end
  end
end
