# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/accounts/_designated_account_successor.html.haml', feature_category: :user_profile do
  context "when user doesn't have an account successor" do
    before do
      allow(view).to receive(:designated_account_successor).and_return(nil)
      render
    end

    it 'renders the `Add account successor` button' do
      expect(rendered).to have_css("button[type='button']", text: s_('Profiles|Add account successor'))
    end

    it 'has the correct form action' do
      expect(rendered).to have_css("form[action='#{profile_designated_beneficiaries_path}']")
    end

    it 'has the correct form fields' do
      expect(rendered).to have_css("input[name='users_designated_beneficiary[type]'][value='successor']",
        visible: :hidden)
      expect(rendered).to have_css("input[name='users_designated_beneficiary[name]']:not([value])")
      expect(rendered).to have_css("input[name='users_designated_beneficiary[relationship]']:not([value])")
      expect(rendered).to have_css("input[name='users_designated_beneficiary[email]']:not([value])")
    end

    it 'has a submit button' do
      expect(rendered).to have_css("button[type='submit']", text: s_('Profiles|Add account successor'))
    end

    it 'contains no account successor' do
      expect(rendered).to have_text(s_('Profiles|No designated account successor assigned.'))
    end
  end

  context "when user has an account successor" do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:account_successor) { build_stubbed(:designated_beneficiary, :successor, user: user) }

    before do
      allow(view).to receive(:designated_account_successor).and_return(account_successor)
      render
    end

    it "doesn't render the `Add account successor` button" do
      expect(rendered).to have_no_selector("button[type='button']", text: s_('Profiles|Add account successor'))
    end

    it 'has the correct form action' do
      expect(rendered).to have_css("form[action='#{profile_designated_beneficiary_path(account_successor)}']")
    end

    it 'has the correct form fields' do
      expect(rendered).to have_css("input[name='users_designated_beneficiary[type]'][value='successor']",
        visible: :hidden)
      expect(rendered).to have_css("input[name='users_designated_beneficiary[name]']" \
        "[value='#{account_successor.name}']")
      expect(rendered).to have_css("input[name='users_designated_beneficiary[relationship]']" \
        "[value='#{account_successor.relationship}']")
      expect(rendered).to have_css("input[name='users_designated_beneficiary[email]']" \
        "[value='#{account_successor.email}']")
    end

    it 'has a submit button with correct text' do
      expect(rendered).to have_css("button[type='submit']", text: s_('Profiles|Update account successor'))
    end

    it 'contains a table with an edit and delete buttons' do
      expect(rendered).to have_css("td[data-label='#{s_('Profiles|Full name')}']", text: account_successor.name)
      expect(rendered).to have_css("td[data-label='#{s_('Profiles|Relationship')}']",
        text: account_successor.relationship)
      expect(rendered).to have_css("td[data-label='#{s_('Profiles|Email address')}']", text: account_successor.email)
      expect(rendered).to have_css("table a[title='#{_('Delete')}'][data-method='delete']" \
        "[href='#{profile_designated_beneficiary_path(account_successor)}']")
      expect(rendered).to have_css("table button[title='#{_('Edit')}']")
    end
  end
end
