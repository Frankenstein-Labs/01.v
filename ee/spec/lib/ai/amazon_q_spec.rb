# frozen_string_literal: true

require 'spec_helper'

using RSpec::Parameterized::TableSyntax

RSpec.describe Ai::AmazonQ, feature_category: :ai_abstraction_layer do
  let_it_be(:organization) { create(:common_organization) }

  let(:application_settings) { ::Gitlab::CurrentSettings.current_application_settings }

  before do
    stub_current_organization(organization)
  end

  describe '#connected?' do
    where(:q_available, :q_ready, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        Ai::Setting.for_organization(organization).update!(amazon_q_ready: q_ready)
        allow(described_class).to receive(:feature_available?).and_return(q_available)
      end

      it 'returns the expected result' do
        expect(described_class.connected?).to be result
      end
    end
  end

  describe '#feature_available?' do
    where(:add_on_purchase, :amazon_q_license_available, :cut_off_date, :result) do
      nil                | true  | 2.days.from_now | true
      :product_analytics | true  | 2.days.from_now | true
      :duo_amazon_q      | true  | 2.days.from_now | true
      :duo_amazon_q      | true  | 2.days.ago      | true
      :duo_pro           | true  | 2.days.from_now | false
      :duo_enterprise    | true  | 2.days.from_now | false
      :duo_pro           | true  | 2.days.from_now | false
      nil                | false | 2.days.from_now | false
    end

    with_them do
      before do
        allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name).and_return(
          build(:cloud_connector_unit_primitive, name: 'amazon_q_integration', cut_off_date: cut_off_date)
        )

        stub_licensed_features(amazon_q: amazon_q_license_available)

        create(:gitlab_subscription_add_on_purchase, add_on_purchase, namespace: nil) if add_on_purchase.present?
      end

      it 'returns the expected result' do
        expect(described_class.feature_available?).to eq(result)
      end
    end

    context 'when :amazon_q_integration UP is missing even if licenced feature is available' do
      before do
        allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name).and_return(nil)
        stub_licensed_features(amazon_q: true)
      end

      it 'returns false' do
        expect(described_class.feature_available?).to be(false)
      end
    end
  end

  describe '#enabled?' do
    context 'with args' do
      let(:namespace) { build(:project_namespace) }
      let(:user) { build(:user) }

      where(:feature_enabled, :connected, :result) do
        true     | true  | true
        true     | false | false
        false    | true  | false
        true     | false | false
      end

      with_them do
        before do
          allow(described_class).to receive_messages(
            feature_available?: feature_enabled,
            connected?: connected
          )
        end

        it { expect(described_class.enabled?).to eq(result) }
      end
    end
  end

  describe '#should_block_service_account?' do
    where(:availability, :expectation) do
      "default_on"  | false
      "default_off" | false
      "never_on"    | true
    end

    with_them do
      it { expect(described_class.should_block_service_account?(availability: availability)).to be(expectation) }
    end
  end

  describe '#ensure_service_account_blocked!' do
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be_with_reload(:service_account_normal) { create(:user, :service_account) }
    let_it_be_with_reload(:service_account_blocked) { create(:user, :service_account, :blocked) }
    let_it_be(:service_account_not_found) { Struct.new(:id).new(999999) }

    context 'with service_account set in application settings' do
      where(:service_account, :expected_service_class, :expected_status, :expected_message) do
        ref(:service_account_normal)     | ::Users::BlockService | true | nil
        ref(:service_account_blocked)    | nil | true | "Service account already blocked. Nothing to do."
      end

      with_them do
        before do
          Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: service_account&.id)
        end

        it 'conditionally block the service account', :aggregate_failures do
          if expected_service_class
            expect_next_instance_of(expected_service_class, current_user) do |instance|
              expect(instance).to receive(:execute).with(service_account).and_call_original
            end
          end

          response = described_class.ensure_service_account_blocked!(current_user: current_user)

          expect(response.success?).to be(expected_status)
          expect(response.message).to be(expected_message)
        end
      end
    end

    context 'with service_account set as argument' do
      it 'conditionally blocks the given service account', :aggregate_failures do
        expect(service_account_normal.blocked?).to be(false)

        response = described_class.ensure_service_account_blocked!(
          current_user: current_user,
          service_account: service_account_normal
        )

        expect(response.success?).to be(true)
        expect(service_account_normal.blocked?).to be(true)
      end
    end
  end

  describe '#ensure_service_account_unblocked!' do
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be_with_reload(:service_account_normal) { create(:user, :service_account) }
    let_it_be_with_reload(:service_account_blocked) { create(:user, :service_account, :blocked) }

    context 'with service_account set in application settings' do
      where(:service_account, :expected_service_class, :expected_status, :expected_message) do
        ref(:service_account_normal)     | nil | true | "Service account already unblocked. Nothing to do."
        ref(:service_account_blocked)    | ::Users::UnblockService | true | nil
      end

      with_them do
        before do
          Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: service_account&.id)
        end

        it 'conditionally block the service account', :aggregate_failures do
          if expected_service_class
            expect_next_instance_of(expected_service_class, current_user) do |instance|
              expect(instance).to receive(:execute).with(service_account).and_call_original
            end
          end

          response = described_class.ensure_service_account_unblocked!(current_user: current_user)

          expect(response.success?).to be(expected_status)
          expect(response.message).to be(expected_message)
        end
      end
    end

    context 'with service_account set as argument' do
      it 'conditionally blocks the given service account', :aggregate_failures do
        expect(service_account_blocked.blocked?).to be(true)

        response = described_class.ensure_service_account_unblocked!(
          current_user: current_user,
          service_account: service_account_blocked
        )

        expect(response.success?).to be(true)
        expect(service_account_blocked.blocked?).to be(false)
      end
    end
  end
end
