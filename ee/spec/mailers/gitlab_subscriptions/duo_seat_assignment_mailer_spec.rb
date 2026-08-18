# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoSeatAssignmentMailer, feature_category: :seat_cost_management do
  include EmailSpec::Matchers

  let_it_be(:user) { build(:user) }

  describe '#duo_pro_email' do
    subject(:email) { described_class.duo_pro_email(user) }

    let(:email_subject) { s_('CodeSuggestions|Welcome to GitLab Duo Pro!') }

    it 'sends mail with expected contents' do
      expect(email).to have_subject(email_subject)
      expect(email).to have_body_text(s_('CodeSuggestions|You have been assigned a GitLab Duo Pro seat'))
    end
  end

  describe '#duo_enterprise_email' do
    subject(:email) { described_class.duo_enterprise_email(user) }

    let(:email_subject) { s_('DuoEnterprise|Welcome to GitLab Duo Enterprise!') }

    it 'sends mail with expected contents' do
      expect(email).to have_subject(email_subject)
      expect(email).to have_body_text(s_('DuoEnterprise|You have been assigned a GitLab Duo Enterprise seat'))
    end
  end
end
