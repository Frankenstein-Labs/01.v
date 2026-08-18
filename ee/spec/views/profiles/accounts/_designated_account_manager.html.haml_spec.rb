# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/accounts/_designated_account_manager.html.haml', feature_category: :user_profile do
  context "when user doesn't have an account manager" do
    before do
      allow(view).to receive(:designated_account_manager).and_return(nil)
      render
    end

    it 'renders the `Add account manager` button' do
      expect(rendered).to have_css("button[type='button']", text: s_('Profiles|Add account manager'))
    end

    it 'has the correct form action' do
      expect(rendered).to have_css("form[action='#{profile_designated_beneficiaries_path}']")
    end

    it 'has the correct form fields' do
      expect(rendered).to have_css("input[name='users_designated_beneficiary[type]'][value='manager']",
        visible: :hidden)
      expect(rendered).to have_css("input[name='users_designated_beneficiary[name]']:not([value])")
      expect(rendered).to have_css("input[name='users_designated_beneficiary[email]']:not([value])")
    end

    it 'has a submit button with correct text' do
      expect(rendered).to have_css("button[type='submit']", text: s_('Profiles|Add account manager'))
    end

    it 'contains no account manager' do
      expect(rendered).to have_text(s_('Profiles|No designated account manager assigned.'))
    end
  end

  context "when user has an account manager" do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:account_manager) { build_stubbed(:designated_beneficiary, :manager, user: user) }

    before do
      allow(view).to receive(:designated_account_manager).and_return(account_manager)
      render
    end

    it "doesn't render the `Add account manager` button" do
      expect(rendered).to have_no_selector("button[type='button']", text: s_('Profiles|Add account manager'))
    end

    it 'has the correct form action' do
      expect(rendered).to have_css("form[action='#{profile_designated_beneficiary_path(account_manager)}']")
    end

    it 'has the correct form fields' do
      expect(rendered).to have_css("input[name='users_designated_beneficiary[type]'][value='manager']",
        visible: :hidden)
      expect(rendered).to have_css("input[name='users_designated_beneficiary[name]']" \
        "[value='#{account_manager.name}']")
      expect(rendered).to have_css("input[name='users_designated_beneficiary[email]']" \
        "[value='#{account_manager.email}']")
    end

    it 'has a submit button with correct text' do
      expect(rendered).to have_css("button[type='submit']", text: s_('Profiles|Update account manager'))
    end

    it 'contains a table with an edit and delete buttons' do
      expect(rendered).to have_css("td[data-label='#{s_('Profiles|Full name')}']", text: account_manager.name)
      expect(rendered).to have_css("td[data-label='#{s_('Profiles|Email address')}']", text: account_manager.email)
      expect(rendered).to have_css("table a[title='#{_('Delete')}'][data-method='delete']" \
        "[href='#{profile_designated_beneficiary_path(account_manager)}']")
      expect(rendered).to have_css("table button[title='#{_('Edit')}']")
    end
  end
end
