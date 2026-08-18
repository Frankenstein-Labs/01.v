# frozen_string_literal: true

RSpec.shared_examples 'targeted message interactions' do
  let_it_be(:targeted_message, freeze: false) { create(:targeted_message, roles: [Gitlab::Access::OWNER]) }

  before do
    create(:targeted_message_namespace, namespace: group, targeted_message: targeted_message)
    sign_in(user)
  end

  it 'is not shown to non-owner', :with_trial_types do
    sign_in(non_owner)
    visit path

    expect(page).not_to have_content("Get access to Premium + GitLab Duo for")
  end

  it 'is shown to owner', :with_trial_types do
    visit path

    expect(page).to have_content("Get access to Premium + GitLab Duo for")
  end

  context 'with disabled targeted message', :with_trial_types do
    before do
      stub_feature_flags(targeted_messages_admin_ui: false)
    end

    it 'is not shown' do
      visit path

      expect(page).not_to have_content("Get access to Premium + GitLab Duo for")
    end
  end
end
