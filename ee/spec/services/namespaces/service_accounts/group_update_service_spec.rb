# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::GroupUpdateService, feature_category: :user_management do
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  let(:service_account_user) { create(:user, :service_account, provisioned_by_group: group) }

  let(:params) do
    {
      name: FFaker::Name.name,
      username: "service_account_#{SecureRandom.hex(8)}",
      email: 'test@test.com',
      group_id: group.id
    }
  end

  subject(:service) { described_class.new(owner, service_account_user, params) }

  describe '#execute' do
    context 'when email confirmation setting is set to hard' do
      before do
        stub_application_setting_enum('email_confirmation_setting', 'hard')
      end

      context 'when the group owns the email domain', :saas do
        before do
          stub_licensed_features(domain_verification: true)
          project = create(:project, group: group)
          create(:pages_domain, project: project, domain: 'test.com')
        end

        it 'updates the email without confirmation', :aggregate_failures do
          result = service.execute

          expect(result.status).to eq(:success)
          expect(result.payload[:user].email).to eq(params[:email])
          expect(result.payload[:user].unconfirmed_email).to be_nil
        end
      end
    end
  end
end
