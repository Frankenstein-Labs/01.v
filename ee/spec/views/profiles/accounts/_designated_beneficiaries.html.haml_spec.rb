# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/accounts/_designated_beneficiaries.html.haml', feature_category: :user_profile do
  let(:user) { build_stubbed(:user) }
  let(:designated_account_manager) { build_stubbed(:designated_beneficiary, :manager) }
  let(:designated_account_successor) { build_stubbed(:designated_beneficiary, :successor) }

  subject do
    render
    rendered
  end

  before do
    allow(view).to receive_messages(
      current_user: user,
      designated_account_manager: designated_account_manager,
      designated_account_successor: designated_account_successor
    )
  end

  context 'when user can designate account beneficiaries' do
    before do
      allow(user).to receive(:can?).with(:create_designated_account_beneficiaries).and_return(true)
    end

    it { is_expected.to have_text(s_('Profiles|Legacy contacts')) }

    it 'renders the designated account manager partial' do
      render
      expect(view).to have_rendered('profiles/accounts/_designated_account_manager')
    end

    it 'renders the designated account successor partial' do
      render
      expect(view).to have_rendered('profiles/accounts/_designated_account_successor')
    end
  end

  context 'when user cannot designate account beneficiaries' do
    before do
      allow(user).to receive(:can?).with(:create_designated_account_beneficiaries).and_return(false)
    end

    it { is_expected.to be_blank }
  end

  context 'when current_user is nil' do
    before do
      allow(view).to receive(:current_user).and_return(nil)
    end

    it { is_expected.to be_blank }
  end
end
