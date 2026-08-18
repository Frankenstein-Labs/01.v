# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CurrentLicense'], :enable_admin_mode, feature_category: :plan_provisioning do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:admin) { create(:admin) }
  let_it_be(:licensee) do
    {
      'Name' => 'User Example',
      'Email' => 'user@example.com',
      'Company' => 'Example Inc.'
    }
  end

  let_it_be(:license) do
    create_current_license(
      { licensee: licensee, cloud_licensing_enabled: true },
      { cloud: true, last_synced_at: Time.current }
    )
  end

  let(:fields) do
    %w[last_sync billable_users_count maximum_user_count users_over_license_count trial has_gitlab_credits_add_on
      subscription_name]
  end

  it { expect(described_class.graphql_name).to eq('CurrentLicense') }
  it { expect(described_class).to include_graphql_fields(*fields) }

  include_examples 'license type fields'

  describe "#users_over_license_count" do
    def query(field_name)
      %(
        {
          currentLicense {
            #{field_name}
          }
        }
      )
    end

    def query_field(field_name)
      GitlabSchema.execute(query(field_name), context: { current_user: admin }).as_json
    end

    it 'returns the number of users over the paid users in the license' do
      create(:historical_data, active_user_count: 15)
      create_current_license(licensee: licensee, seats: 10)

      result_as_json = query_field('usersOverLicenseCount')

      expect(result_as_json['data']['currentLicense']['usersOverLicenseCount']).to eq(5)
    end
  end

  describe 'field values' do
    subject { resolve_field(field_name, license) }

    describe 'last_sync' do
      let(:field_name) { :last_sync }

      it { is_expected.to eq(license.last_synced_at) }
    end

    describe 'billable_users_count' do
      let(:field_name) { :billable_users_count }

      before do
        allow(license).to receive(:daily_billable_users_count).and_return(10)
      end

      it { is_expected.to eq(10) }
    end

    describe 'maximum_user_count' do
      let(:field_name) { :maximum_user_count }

      before do
        allow(license).to receive(:maximum_user_count).and_return(20)
      end

      it { is_expected.to eq(20) }
    end

    describe 'trial' do
      let(:field_name) { :trial }

      where trial: [true, false]

      with_them do
        before do
          allow(license).to receive(:trial?).and_return(trial)
        end

        it { is_expected.to eq(trial) }
      end
    end

    describe 'has_gitlab_credits_add_on' do
      let(:field_name) { :has_gitlab_credits_add_on }

      where has_add_on: [true, false]

      with_them do
        before do
          allow(License).to receive(:has_active_gitlab_credits_add_on?).and_return(has_add_on)
        end

        it { is_expected.to eq(has_add_on) }
      end
    end

    describe 'subscription_name' do
      let(:field_name) { :subscription_name }

      before do
        allow(license).to receive(:subscription_name).and_return('A-S00000001')
      end

      it { is_expected.to eq('A-S00000001') }
    end
  end
end
