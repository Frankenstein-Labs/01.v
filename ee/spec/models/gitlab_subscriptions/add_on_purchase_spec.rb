# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchase, feature_category: :plan_provisioning do
  subject { build(:gitlab_subscription_add_on_purchase) }

  it { is_expected.to include_module(EachBatch) }

  describe 'constants' do
    it { expect(described_class::CLEANUP_DELAY_PERIOD).to be_a(ActiveSupport::Duration) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:add_on).with_foreign_key(:subscription_add_on_id).inverse_of(:add_on_purchases) }
    it { is_expected.to belong_to(:namespace).optional(true) }
    it { is_expected.to belong_to(:organization).inverse_of(:add_on_purchases) }

    it do
      is_expected.to have_many(:assigned_users)
        .class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:add_on_purchase)
    end

    it do
      is_expected.to have_many(:assigned_users)
        .dependent(:destroy).class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:add_on_purchase)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:add_on) }
    it { is_expected.to validate_presence_of(:expires_on) }
    it { is_expected.to validate_presence_of(:started_at) }

    context 'when validating namespace' do
      context 'when on .com', :saas do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:group_namespace) { create(:group) }
        let_it_be(:sub_group_namespace) { create(:group, parent: group_namespace) }
        let_it_be(:project_namespace) { create(:project_namespace) }
        let_it_be(:user_namespace) { create(:user_namespace) }

        where(:namespace, :result) do
          ref(:group_namespace)     | true
          ref(:sub_group_namespace) | false
          ref(:project_namespace)   | false
          ref(:user_namespace)      | false
          nil                       | false
        end

        with_them do
          it 'validates the namespace correctly' do
            record = build(:gitlab_subscription_add_on_purchase, namespace: namespace)

            expect(record.valid?).to eq(result)
            expect(record.errors.of_kind?(:namespace, :invalid)).to eq(!result)
          end
        end
      end

      context 'when not on .com' do
        it { is_expected.not_to validate_presence_of(:namespace) }
      end
    end

    it { is_expected.to validate_uniqueness_of(:subscription_add_on_id).scoped_to(:namespace_id) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than_or_equal_to(1) }

    it { is_expected.to validate_presence_of(:purchase_xid) }
    it { is_expected.to validate_length_of(:purchase_xid).is_at_most(255) }
  end

  describe 'callbacks' do
    describe '#set_subscription_add_on_uid' do
      context 'when creating a new record' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase, add_on: add_on) }

        it 'sets subscription_add_on_uid from the add_on name enum value' do
          add_on_purchase.save!

          expect(add_on_purchase.subscription_add_on_uid).to eq(GitlabSubscriptions::AddOn.names[:duo_enterprise])
        end
      end

      context 'when creating a new record with an unsaved add_on association' do
        let(:add_on) { build(:gitlab_subscription_add_on, :duo_enterprise) }
        let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase, add_on: add_on) }

        it 'sets subscription_add_on_uid after the association is autosaved on create' do
          add_on_purchase.save!

          expect(add_on_purchase.subscription_add_on_uid).to eq(GitlabSubscriptions::AddOn.names[:duo_enterprise])
        end
      end

      context 'when updating with a different add_on' do
        let_it_be(:original_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
        let_it_be(:new_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be_with_reload(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, add_on: original_add_on)
        end

        it 'updates subscription_add_on_uid' do
          add_on_purchase.update!(add_on: new_add_on)

          expect(add_on_purchase.subscription_add_on_uid).to eq(GitlabSubscriptions::AddOn.names[:duo_enterprise])
        end
      end

      context 'when updating without changing add_on' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
        let_it_be_with_reload(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }

        it 'does not update subscription_add_on_uid' do
          original_uid = add_on_purchase.subscription_add_on_uid

          add_on_purchase.update!(quantity: 10)

          expect(add_on_purchase.reload.subscription_add_on_uid).to eq(original_uid)
        end
      end
    end
  end

  describe 'scopes' do
    shared_context 'with add-on purchases' do
      let_it_be(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      let_it_be(:expired_gitlab_duo_pro_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, :expired, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, started_at: Date.current)
      end

      let_it_be(:expired_gitlab_duo_pro_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, expires_on: Date.current)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:future_dated_gitlab_duo_pro_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, :future_dated, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:expired_product_analytics_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, :expired, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on, started_at: Date.current)
      end

      let_it_be(:expired_product_analytics_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on, expires_on: Date.current)
      end

      let_it_be(:active_product_analytics_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:future_dated_product_analytics_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, :future_dated, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:user) { create(:user) }

      before_all do
        expired_gitlab_duo_pro_purchase_as_owner.namespace.add_owner(user)
        active_gitlab_duo_pro_purchase_as_guest.namespace.add_guest(user)
        expired_gitlab_duo_pro_purchase_as_reporter.namespace.add_reporter(user)
        active_gitlab_duo_pro_purchase_as_developer.namespace.add_developer(user)
        future_dated_gitlab_duo_pro_purchase_as_maintainer.namespace.add_maintainer(user)

        expired_product_analytics_purchase_as_owner.namespace.add_owner(user)
        active_product_analytics_purchase_as_guest.namespace.add_guest(user)
        expired_product_analytics_purchase_as_reporter.namespace.add_reporter(user)
        active_product_analytics_purchase_as_developer.namespace.add_developer(user)
        future_dated_product_analytics_purchase_as_maintainer.namespace.add_maintainer(user)
      end
    end

    describe '.active' do
      subject(:active_purchases) { described_class.active }

      include_context 'with add-on purchases'

      it 'returns all the purchases that are not expired' do
        expect(active_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_guest,
            active_gitlab_duo_pro_purchase_as_developer,
            active_gitlab_duo_pro_purchase_unrelated,
            active_product_analytics_purchase_as_guest,
            active_product_analytics_purchase_as_developer,
            active_product_analytics_purchase_unrelated
          ]
        )
      end
    end

    describe '.ready_for_cleanup' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:active_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          expires_on: Date.current
        )
      end

      let_it_be(:ready_for_clean_up_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          expires_on: (described_class::CLEANUP_DELAY_PERIOD + 1.day).ago.to_date
        )
      end

      it 'returns all ready for cleanup add on purchases' do
        expect(described_class.ready_for_cleanup).to match_array(ready_for_clean_up_add_on_purchase)
      end
    end

    describe '.trial' do
      include_context 'with add-on purchases'

      let_it_be(:gitlab_duo_pro_purchase_trial) do
        create(:gitlab_subscription_add_on_purchase, :trial, add_on: gitlab_duo_pro_add_on)
      end

      subject(:trials) { described_class.trial }

      it 'returns all the purchases that are not expired' do
        expect(trials).to match_array([gitlab_duo_pro_purchase_trial])
      end
    end

    describe '.non_trial' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:gitlab_duo_pro_purchase_true_trial) do
        create(:gitlab_subscription_add_on_purchase, trial: true, add_on: add_on)
      end

      let_it_be(:gitlab_duo_pro_purchase_false_trial) do
        create(:gitlab_subscription_add_on_purchase, trial: false, add_on: add_on)
      end

      subject(:non_trials) { described_class.non_trial }

      it 'returns all the purchases that are not expired' do
        expect(non_trials).to match_array([gitlab_duo_pro_purchase_false_trial])
      end
    end

    describe '.by_add_on_name' do
      subject(:by_name_purchases) { described_class.by_add_on_name(name) }

      include_context 'with add-on purchases'

      context 'when name is: code_suggestions' do
        let(:name) { 'code_suggestions' }

        it 'returns all the purchases related to gitlab_duo_pro' do
          expect(by_name_purchases).to match_array(
            [
              expired_gitlab_duo_pro_purchase_as_owner,
              active_gitlab_duo_pro_purchase_as_guest,
              expired_gitlab_duo_pro_purchase_as_reporter,
              active_gitlab_duo_pro_purchase_as_developer,
              future_dated_gitlab_duo_pro_purchase_as_maintainer,
              active_gitlab_duo_pro_purchase_unrelated
            ]
          )
        end
      end

      context 'when name is set to anything else' do
        let(:name) { 'foo-bar' }

        it 'returns empty collection' do
          expect(by_name_purchases).to eq([])
        end
      end
    end

    describe '.by_namespace' do
      subject(:result) { described_class.by_namespace(namespace_id) }

      include_context 'with add-on purchases'

      context 'when record with given namespace_id exists' do
        let(:namespace_id) { active_gitlab_duo_pro_purchase_as_developer.namespace_id }

        it { is_expected.to contain_exactly(active_gitlab_duo_pro_purchase_as_developer) }

        context 'when namespace record is passed' do
          subject { described_class.by_namespace(active_gitlab_duo_pro_purchase_as_developer.namespace) }

          it { is_expected.to contain_exactly(active_gitlab_duo_pro_purchase_as_developer) }
        end
      end

      context 'when record with given namespace_id does not exist' do
        let(:namespace_id) { non_existing_record_id }

        it { is_expected.to match_array([]) }
      end

      context 'when nil is given' do
        let(:namespace_id) { nil }

        context 'and the record exist' do
          let(:add_on_purchase_with_namespace_id_nil) do
            create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, namespace_id: nil)
          end

          it { is_expected.to contain_exactly(add_on_purchase_with_namespace_id_nil) }
        end

        context 'and the record does not exist' do
          it { is_expected.to match_array([]) }
        end
      end
    end

    describe '.for_self_managed' do
      include_context 'with add-on purchases'

      let_it_be(:self_managed_purchase) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, namespace: nil)
      end

      subject(:self_managed_purchases) { described_class.for_self_managed }

      it 'returns only add-on purchases without a namespace' do
        expect(self_managed_purchases).to contain_exactly(self_managed_purchase)
      end
    end

    describe '.for_gitlab_duo_pro' do
      subject(:gitlab_duo_pro_purchases) { described_class.for_gitlab_duo_pro }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to gitlab duo' do
        expect(gitlab_duo_pro_purchases).to match_array(
          [
            expired_gitlab_duo_pro_purchase_as_owner,
            active_gitlab_duo_pro_purchase_as_guest,
            expired_gitlab_duo_pro_purchase_as_reporter,
            active_gitlab_duo_pro_purchase_as_developer,
            future_dated_gitlab_duo_pro_purchase_as_maintainer,
            active_gitlab_duo_pro_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_product_analytics' do
      subject(:product_analytics_purchases) { described_class.for_product_analytics }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to product_analytics' do
        expect(product_analytics_purchases).to match_array(
          [
            expired_product_analytics_purchase_as_owner,
            active_product_analytics_purchase_as_guest,
            expired_product_analytics_purchase_as_reporter,
            active_product_analytics_purchase_as_developer,
            future_dated_product_analytics_purchase_as_maintainer,
            active_product_analytics_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_duo_enterprise' do
      subject(:duo_enterprise_add_on_purchases) { described_class.for_duo_enterprise }

      it { expect(duo_enterprise_add_on_purchases).to be_empty }

      context 'with duo_enterprise purchase' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }

        it { expect(duo_enterprise_add_on_purchases).to eq [duo_enterprise_add_on] }
      end

      context 'with other purchases' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
        let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

        it 'returns only duo_enterprise add-on purchases' do
          expect(duo_enterprise_add_on_purchases).to eq [duo_enterprise_add_on]
        end
      end
    end

    describe '.for_duo_amazon_q' do
      subject(:duo_amazon_q_add_on_purchases) { described_class.for_duo_amazon_q }

      it { expect(duo_amazon_q_add_on_purchases).to be_empty }

      context 'with duo_amazon_q purchase' do
        let!(:duo_amazon_q_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

        it { expect(duo_amazon_q_add_on_purchases).to eq [duo_amazon_q_add_on_purchase] }
      end

      context 'with other purchases' do
        let!(:duo_amazon_q_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
        let!(:duo_pro_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

        it 'returns only duo_amazon_q add-on purchases' do
          expect(duo_amazon_q_add_on_purchases).to eq [duo_amazon_q_add_on_purchase]
        end
      end
    end

    describe '.for_duo_core' do
      subject(:duo_core_add_on_purchases) { described_class.for_duo_core }

      it { expect(duo_core_add_on_purchases).to be_empty }

      context 'with duo_core purchase' do
        let!(:duo_core_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_core) }

        it { expect(duo_core_add_on_purchases).to eq [duo_core_add_on] }
      end

      context 'with other purchases' do
        let!(:duo_core_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_core) }
        let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

        it 'returns only duo_core add-on purchases' do
          expect(duo_core_add_on_purchases).to eq [duo_core_add_on]
        end
      end
    end

    describe '.for_self_hosted_dap' do
      subject(:self_hosted_dap_add_on_purchases) { described_class.for_self_hosted_dap }

      it { expect(self_hosted_dap_add_on_purchases).to be_empty }

      context 'with self_hosted_dap purchase' do
        let!(:self_hosted_dap_add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_hosted_dap)
        end

        it { expect(self_hosted_dap_add_on_purchases).to eq [self_hosted_dap_add_on_purchase] }
      end

      context 'with other purchases' do
        let!(:self_hosted_dap_add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_hosted_dap)
        end

        let!(:duo_pro_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

        it 'returns only self_hosted_dap add-on purchases' do
          expect(self_hosted_dap_add_on_purchases).to eq [self_hosted_dap_add_on_purchase]
        end
      end
    end

    describe '.for_gitlab_credits' do
      subject(:gitlab_credits_add_on_purchases) { described_class.for_gitlab_credits }

      it { expect(gitlab_credits_add_on_purchases).to be_empty }

      context 'with gitlab_credits purchase' do
        let_it_be(:gitlab_credits_add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits)
        end

        it { expect(gitlab_credits_add_on_purchases).to eq [gitlab_credits_add_on_purchase] }

        it 'returns only gitlab_credits add-on purchases when there are other purchases' do
          create(:gitlab_subscription_add_on_purchase, :duo_pro)

          expect(gitlab_credits_add_on_purchases).to eq [gitlab_credits_add_on_purchase]
        end
      end
    end

    describe '.for_secrets_manager' do
      subject(:secrets_manager_add_on_purchases) { described_class.for_secrets_manager }

      it { expect(secrets_manager_add_on_purchases).to be_empty }

      context 'with secrets_manager purchase' do
        let_it_be(:secrets_manager_add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :secrets_manager)
        end

        it { expect(secrets_manager_add_on_purchases).to eq [secrets_manager_add_on_purchase] }

        it 'returns only secrets_manager add-on purchases when there are other purchases' do
          create(:gitlab_subscription_add_on_purchase, :duo_pro)

          expect(secrets_manager_add_on_purchases).to eq [secrets_manager_add_on_purchase]
        end
      end
    end

    describe '.for_duo_pro_or_duo_enterprise' do
      subject(:duo_pro_or_duo_enterprise_add_on_purchases) { described_class.for_duo_pro_or_duo_enterprise }

      it { expect(duo_pro_or_duo_enterprise_add_on_purchases).to be_empty }

      context 'with duo_enterprise purchase' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }

        it { expect(duo_pro_or_duo_enterprise_add_on_purchases).to eq [duo_enterprise_add_on] }
      end

      context 'with duo_pro purchase' do
        let!(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

        it { expect(duo_pro_or_duo_enterprise_add_on_purchases).to eq [gitlab_duo_pro_add_on] }
      end

      context 'with other purchases' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
        let!(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }
        let!(:product_analytics_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }

        it 'returns both gitlab_duo_pro and duo_enterprise add-ons' do
          expect(duo_pro_or_duo_enterprise_add_on_purchases).to match_array(
            [duo_enterprise_add_on, gitlab_duo_pro_add_on]
          )
        end
      end
    end

    describe '.for_duo_core_pro_or_enterprise' do
      subject(:add_on_purchases) { described_class.for_duo_core_pro_or_enterprise }

      let_it_be(:duo_amazon_q_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
      let_it_be(:duo_enterprise_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
      let_it_be(:duo_pro_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }
      let_it_be(:duo_core_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core) }
      let_it_be(:self_hosted_dap_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_hosted_dap) }
      let_it_be(:product_analytics_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }

      it 'returns Duo Core, Pro and Enterprise' do
        expect(add_on_purchases).to contain_exactly(
          duo_core_add_on_purchase, duo_pro_add_on_purchase, duo_enterprise_add_on_purchase
        )
      end
    end

    describe '.for_duo_core_pro_enterprise_or_self_hosted_dap' do
      subject(:add_on_purchases) { described_class.for_duo_core_pro_enterprise_or_self_hosted_dap }

      let_it_be(:duo_amazon_q_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
      let_it_be(:duo_enterprise_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
      let_it_be(:duo_pro_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }
      let_it_be(:duo_core_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core) }
      let_it_be(:self_hosted_dap_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_hosted_dap) }
      let_it_be(:product_analytics_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }

      it 'returns Duo Core, Pro, Enterprise and Self-Hosted DAP' do
        expect(add_on_purchases).to contain_exactly(
          duo_core_add_on_purchase,
          duo_pro_add_on_purchase,
          duo_enterprise_add_on_purchase,
          self_hosted_dap_add_on_purchase
        )
      end
    end

    describe '.for_duo_add_ons' do
      subject(:duo_add_ons_purchases) { described_class.for_duo_add_ons }

      let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
      let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }
      let_it_be(:duo_core_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_core) }
      let_it_be(:duo_amazon_q_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
      let_it_be(:self_hosted_dap_add_on) { create(:gitlab_subscription_add_on_purchase, :self_hosted_dap) }
      let_it_be(:gitlab_credits_add_on) { create(:gitlab_subscription_add_on_purchase, :gitlab_credits) }
      let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }

      it 'returns all duo add-ons' do
        expect(duo_add_ons_purchases).to contain_exactly(
          duo_enterprise_add_on,
          duo_pro_add_on,
          duo_core_add_on,
          duo_amazon_q_add_on,
          self_hosted_dap_add_on,
          gitlab_credits_add_on
        )
      end
    end

    describe '.for_active_add_ons' do
      using RSpec::Parameterized::TableSyntax

      subject(:active_add_on_purchases) { described_class.for_active_add_ons(add_on_names, resource) }

      let_it_be(:user) { create(:user) }
      let_it_be(:group_1) { create(:group) }
      let_it_be(:group_2) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group_1) }

      let_it_be(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
      let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      let_it_be(:active_pro_purchase_for_group_1) do
        create(:gitlab_subscription_add_on_purchase, :active, add_on: gitlab_duo_pro_add_on, namespace: group_1)
      end

      let_it_be(:active_pro_purchase_for_group_2) do
        create(:gitlab_subscription_add_on_purchase, :active, add_on: gitlab_duo_pro_add_on, namespace: group_2)
      end

      let_it_be(:active_analytics_purchase_for_group_2) do
        create(:gitlab_subscription_add_on_purchase, :active, add_on: product_analytics_add_on, namespace: group_2)
      end

      let_it_be(:active_analytics_purchase_for_self_managed) do
        create(:gitlab_subscription_add_on_purchase, :active, :self_managed, add_on: product_analytics_add_on)
      end

      # rubocop:disable Layout/LineLength -- for better readability
      where(:gitlab_com, :resource, :add_on_names, :result) do
        true  | ref(:group_1) | %w[code_suggestions product_analytics] | [ref(:active_pro_purchase_for_group_1)]
        true  | ref(:group_2) | %w[code_suggestions product_analytics] | [ref(:active_pro_purchase_for_group_2), ref(:active_analytics_purchase_for_group_2)]
        true  | ref(:project) | %w[code_suggestions product_analytics] | [ref(:active_pro_purchase_for_group_1)]
        true  | ref(:group_1) | %w[product_analytics]                  | []
        true  | ref(:user)    | %w[code_suggestions product_analytics] | [ref(:active_pro_purchase_for_group_1)]
        true  | :instance     | %w[code_suggestions product_analytics] | [ref(:active_analytics_purchase_for_self_managed)]
        true  | nil           | %w[code_suggestions]                   | [ref(:active_pro_purchase_for_group_1), ref(:active_pro_purchase_for_group_2)]
        false | :instance     | %w[code_suggestions product_analytics] | [ref(:active_analytics_purchase_for_self_managed)]
        false | ref(:group_1) | %w[code_suggestions product_analytics] | [ref(:active_analytics_purchase_for_self_managed)]
        false | ref(:project) | %w[code_suggestions product_analytics] | [ref(:active_analytics_purchase_for_self_managed)]
        false | ref(:user)    | %w[code_suggestions product_analytics] | [ref(:active_analytics_purchase_for_self_managed)]
        false | nil           | %w[code_suggestions product_analytics] | [ref(:active_analytics_purchase_for_self_managed)]
        false | nil           | %w[code_suggestions]                   | []
      end
      # rubocop:enable Layout/LineLength

      with_them do
        before do
          stub_saas_features(gitlab_com_subscriptions: gitlab_com)

          group_1.add_member(user, :developer)
        end

        it 'returns the expected results' do
          expect(active_add_on_purchases).to match_array(result)
        end
      end
    end

    describe '.for_seat_assignable_duo_add_ons' do
      subject(:seat_assignable_duo_add_on_purchases) { described_class.for_seat_assignable_duo_add_ons }

      let_it_be(:duo_core_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core) }
      let_it_be(:product_analytics_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }
      let_it_be(:duo_enterprise_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
      let_it_be(:duo_pro_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

      it 'returns duo add-on purchases with seat assignments supported' do
        expect(seat_assignable_duo_add_on_purchases).to contain_exactly(
          duo_enterprise_add_on_purchase, duo_pro_add_on_purchase
        )
      end
    end

    describe '.for_user', :saas do
      subject(:user_purchases) { described_class.for_user(user) }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to the user top level namespaces' do
        expect(user_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_guest,
            active_product_analytics_purchase_as_guest,
            expired_gitlab_duo_pro_purchase_as_owner,
            expired_gitlab_duo_pro_purchase_as_reporter,
            active_gitlab_duo_pro_purchase_as_developer,
            future_dated_gitlab_duo_pro_purchase_as_maintainer,
            expired_product_analytics_purchase_as_owner,
            expired_product_analytics_purchase_as_reporter,
            active_product_analytics_purchase_as_developer,
            future_dated_product_analytics_purchase_as_maintainer
          ]
        )
      end
    end

    describe '.assigned_to_user', :saas do
      include_context 'with add-on purchases'

      before_all do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_as_guest
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_as_developer
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: future_dated_gitlab_duo_pro_purchase_as_maintainer
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: expired_gitlab_duo_pro_purchase_as_owner
        )
      end

      subject(:user_purchases) { described_class.assigned_to_user(user) }

      it 'returns all active purchases related to the user add-on assignments' do
        expect(user_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_guest,
            active_gitlab_duo_pro_purchase_as_developer
          ]
        )
      end
    end

    describe '.requiring_assigned_users_refresh' do
      it 'returns correct add_on_purchases' do
        all_add_on_names = GitlabSubscriptions::AddOn.names.keys.map do |name|
          name == 'code_suggestions' ? :duo_pro : name.to_sym
        end

        add_on_records = all_add_on_names.index_with do |add_on_name|
          create(:gitlab_subscription_add_on, add_on_name)
        end

        seat_assignable_add_on_names = %i[duo_pro duo_enterprise]

        seat_assignable_add_on_names.each do |add_on_name|
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_records[add_on_name],
            last_assigned_users_refreshed_at: 1.hour.ago
          )
        end

        stale_refreshed_purchases = seat_assignable_add_on_names.index_with do |add_on_name|
          create(
            :gitlab_subscription_add_on_purchase,
            add_on: add_on_records[add_on_name],
            last_assigned_users_refreshed_at: 21.hours.ago
          )
        end

        never_refreshed_purchases = all_add_on_names.index_with do |add_on_name|
          create(:gitlab_subscription_add_on_purchase, add_on: add_on_records[add_on_name])
        end

        expected = [
          never_refreshed_purchases[:duo_pro],
          never_refreshed_purchases[:duo_enterprise],
          stale_refreshed_purchases[:duo_pro],
          stale_refreshed_purchases[:duo_enterprise]
        ]

        expect(described_class.requiring_assigned_users_refresh(5))
          .to match_array(expected)
      end

      it 'accepts limit param' do
        duo_pro_add_on = create(:gitlab_subscription_add_on, :duo_pro)
        duo_enterprise_add_on = create(:gitlab_subscription_add_on, :duo_enterprise)

        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on)
        create(:gitlab_subscription_add_on_purchase, add_on: duo_enterprise_add_on)

        expect(described_class.requiring_assigned_users_refresh(1).size).to eq 1
      end
    end

    describe '.find_by_namespace_and_add_on' do
      subject(:find_by_namespace_and_add_on) { described_class.find_by_namespace_and_add_on }

      let_it_be(:namespace) { create(:group) }

      let_it_be(:add_on_1) { create(:gitlab_subscription_add_on, :duo_pro) }
      let_it_be(:add_on_2) { create(:gitlab_subscription_add_on, :product_analytics) }

      let_it_be(:add_on_purchase_1) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_1) }
      let_it_be(:add_on_purchase_2) do
        create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on_1)
      end

      let_it_be(:add_on_purchase_3) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_2) }
      let_it_be(:add_on_purchase_4) do
        create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on_2)
      end

      it 'filters by namespace and add-on' do
        expect(described_class.find_by_namespace_and_add_on(nil, add_on_1)).to eq add_on_purchase_1
        expect(described_class.find_by_namespace_and_add_on(namespace, add_on_1)).to eq add_on_purchase_2
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:name).to(:add_on).with_prefix }
    it { is_expected.to delegate_method(:seat_assignable?).to(:add_on).with_prefix }
  end

  describe '.uniq_add_on_names' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

    before_all do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on)
      create(:gitlab_subscription_add_on_purchase, add_on: add_on)
    end

    subject(:add_on_names) { described_class.uniq_add_on_names }

    it { is_expected.to match_array('code_suggestions') }
  end

  describe '.uniq_normalized_add_on_names' do
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    before_all do
      create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on)
      create(:gitlab_subscription_add_on_purchase, add_on: duo_enterprise_add_on)
    end

    subject(:normalized_names) { described_class.uniq_normalized_add_on_names }

    it 'normalizes code_suggestions to duo_pro' do
      expect(normalized_names).to match_array(%w[duo_pro duo_enterprise])
    end
  end

  describe '.uniq_namespace_ids' do
    let_it_be(:namespace_1) { create(:group) }
    let_it_be(:namespace_2) { create(:group) }

    let_it_be(:add_on_1) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:add_on_2) { create(:gitlab_subscription_add_on, :product_analytics) }

    let_it_be(:add_on_purchase_1) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_1) }
    let_it_be(:add_on_purchase_2) do
      create(:gitlab_subscription_add_on_purchase, namespace: namespace_1, add_on: add_on_1)
    end

    let_it_be(:add_on_purchase_3) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_2) }
    let_it_be(:add_on_purchase_4) do
      create(:gitlab_subscription_add_on_purchase, namespace: namespace_1, add_on: add_on_2)
    end

    let_it_be(:add_on_purchase_5) do
      create(:gitlab_subscription_add_on_purchase, namespace: namespace_2, add_on: add_on_2)
    end

    subject(:namespace_ids) { described_class.uniq_namespace_ids }

    it { is_expected.to match_array([namespace_1.id, namespace_2.id]) }
  end

  describe '.next_candidate_requiring_assigned_users_refresh' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase_fresh) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
    end

    subject(:next_candidate) { described_class.next_candidate_requiring_assigned_users_refresh }

    context 'when there are stale records' do
      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 21.hours.ago)
      end

      it 'returns the stale record' do
        expect(next_candidate).to eq(add_on_purchase_stale)
      end

      context 'when there is stale records with nil refreshed_at' do
        it 'returns record with nil refreshed_at as next candidate' do
          result = create(:gitlab_subscription_add_on_purchase, add_on: add_on)

          expect(next_candidate).to eq(result)
        end
      end

      context 'when there is stale record with earlier refreshed_at' do
        it 'returns record with earlier refreshed_at as next candidate' do
          result = create(
            :gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago
          )

          expect(next_candidate).to eq(result)
        end
      end
    end

    it 'returns nil when there are no stale records' do
      expect(next_candidate).to be_nil
    end
  end

  describe '.find_for_unit_primitive' do
    subject(:add_on_purchases) { described_class.find_for_unit_primitive(unit_primitive_name, resource) }

    let(:unit_primitive_name) { :complete_code }
    let_it_be(:group) { create(:group) }

    shared_examples 'finds add-on purchases' do
      context 'when resource is nil' do
        let(:resource) { nil }

        it 'raises an error' do
          expect { add_on_purchases }
            .to raise_error(ArgumentError, 'resource must be :instance, or a User, Group or Project')
        end
      end

      context 'when resource is not a User, Group, Project or :instance' do
        let(:resource) { 'invalid_resource' }

        it 'raises an error' do
          expect { add_on_purchases }
            .to raise_error(ArgumentError, 'resource must be :instance, or a User, Group or Project')
        end
      end

      context 'when active purchases exist' do
        let(:add_on_1) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace) }
        let(:add_on_2) { create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: namespace) }

        context 'when the unit primitive exists' do
          before do
            allow(::Gitlab::CloudConnector::DataModel::UnitPrimitive)
              .to receive(:find_by_name)
              .and_return(build(:cloud_connector_unit_primitive, :complete_code))
          end

          it 'returns matching add-on purchases' do
            expect(add_on_purchases).to match_array([add_on_1])
          end
        end

        context 'when the unit primitive does not exist' do
          before do
            allow(::Gitlab::CloudConnector::DataModel::UnitPrimitive)
              .to receive(:find_by_name)
              .and_return(nil)
          end

          it { is_expected.to be_empty }
        end
      end

      context 'when no active purchases exist' do
        it { is_expected.to be_empty }
      end
    end

    context 'with Group resource', :saas do
      let(:resource) { namespace }
      let(:namespace) { group }

      it_behaves_like 'finds add-on purchases'
    end

    context 'with User resource', :saas do
      let_it_be(:user) { create(:user) }

      let(:resource) { user }
      let(:namespace) { group }

      before_all do
        group.add_developer(user)
      end

      it_behaves_like 'finds add-on purchases'
    end

    context 'with Project resource', :saas do
      let_it_be(:project) { create(:project, namespace: group) }

      let(:resource) { project }
      let(:namespace) { group }

      it_behaves_like 'finds add-on purchases'
    end

    context 'with :instance resource' do
      let(:resource) { :instance }
      let(:namespace) { nil }

      it_behaves_like 'finds add-on purchases'
    end
  end

  describe '.exists_for_unit_primitive?' do
    subject(:exists_for_unit_primitive?) { described_class.exists_for_unit_primitive?(:complete_code, :instance) }

    let_it_be(:duo_pro) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:duo_pro_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_pro) }

    before do
      allow(::Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
        .with(:complete_code)
        .and_return(build(:cloud_connector_unit_primitive, add_ons: cloud_connector_add_ons))
    end

    context 'when no add-on exist for unit primitive' do
      let(:cloud_connector_add_ons) { build_list(:cloud_connector_add_on, 1, name: 'other') }

      it { is_expected.to be(false) }
    end

    context 'when an add-on exists for unit primitive' do
      let(:cloud_connector_add_ons) { build_list(:cloud_connector_add_on, 1, name: 'duo_pro') }

      it { is_expected.to be(true) }
    end
  end

  context 'when finding active Duo add-ons' do
    let_it_be(:unrelated_group) { create(:group) }
    let_it_be(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

    let_it_be(:active_pro_purchase_for_dot_com) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
    end

    let_it_be(:active_analytics_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
    end

    let_it_be_with_reload(:active_pro_purchase_for_self_managed) do
      create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: gitlab_duo_pro_add_on)
    end

    describe '.find_for_active_duo_add_ons' do
      subject(:add_on_purchases) { described_class.find_for_active_duo_add_ons(resource) }

      context 'when scoped to namespace on gitlab.com', :saas do
        let(:resource) { active_pro_purchase_for_dot_com.namespace }

        it 'returns the correct records' do
          expect(add_on_purchases).to match_array([active_pro_purchase_for_dot_com])
        end

        context 'when no active Duo add-ons exist' do
          let(:resource) { unrelated_group }

          it { is_expected.to be_empty }
        end
      end

      context 'when scoped to instance on self-managed' do
        let(:resource) { :instance }

        it 'returns the correct records' do
          expect(add_on_purchases).to match_array([active_pro_purchase_for_self_managed])
        end

        context 'when no active Duo add-ons exist' do
          before do
            active_pro_purchase_for_self_managed.update!(expires_on: 1.day.ago)
          end

          it { is_expected.to be_empty }
        end
      end
    end

    describe '.active_duo_add_ons_exist?' do
      subject(:active_duo_add_ons_exist?) { described_class.active_duo_add_ons_exist?(resource) }

      context 'when scoped to namespace on gitlab.com', :saas do
        let(:resource) { active_pro_purchase_for_dot_com.namespace }

        it { is_expected.to be(true) }

        context 'when no active Duo add-ons exist' do
          let(:resource) { unrelated_group }

          it { is_expected.to be(false) }
        end
      end

      context 'when scoped to instance on self-managed' do
        let(:resource) { :instance }

        it { is_expected.to be(true) }

        context 'when no active Duo add-ons exist' do
          before do
            active_pro_purchase_for_self_managed.update!(expires_on: 1.day.ago)
          end

          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe '#already_assigned?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    let_it_be(:user) { create(:user) }

    subject { add_on_purchase.already_assigned?(user) }

    context 'when the user has been already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it { is_expected.to be(true) }
    end

    context 'when user is not already assigned' do
      it { is_expected.to be(false) }
    end
  end

  describe '#active?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.active? }

    it { is_expected.to be(true) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to be(false) } }
    end
  end

  describe '#expired?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.expired? }

    it { is_expected.to be(false) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to be(true) } }
    end
  end

  describe '#delete_ineligible_user_assignments_in_batches!' do
    let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro) }

    let_it_be(:eligible_user) { create(:user) }
    let_it_be_with_reload(:ineligible_user) { create(:user) }

    let(:expected_log) do
      {
        message: 'Ineligible UserAddOnAssignments destroyed',
        user_ids: [ineligible_user.id],
        add_on: 'code_suggestions',
        add_on_purchase: add_on_purchase.id,
        namespace: add_on_purchase.namespace.path
      }
    end

    subject(:result) { add_on_purchase.delete_ineligible_user_assignments_in_batches! }

    context 'with assigned_users records' do
      before do
        add_on_purchase.assigned_users.create!(user: eligible_user)
        add_on_purchase.assigned_users.create!(user: ineligible_user)
      end

      it 'does not log' do
        expect(Gitlab::AppLogger).not_to receive(:info).with(expected_log)

        result
      end

      context 'with ineligible user' do
        before do
          add_on_purchase.namespace.add_guest(eligible_user)
        end

        it 'removes only ineligible user assignments' do
          expect(add_on_purchase.reload.assigned_users.count).to eq(2)

          expect do
            expect(result).to eq(1)
          end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

          expect(add_on_purchase.reload.assigned_users.where(user: eligible_user).count).to eq(1)
        end

        it 'logs deleted user add-on assignements' do
          expect(Gitlab::AppLogger).to receive(:info).with(expected_log)

          result
        end
      end

      it 'accepts batch_size and deletes the assignments in batch' do
        expect(GitlabSubscriptions::UserAddOnAssignment).to receive(:pluck_user_ids).twice.and_call_original

        result = add_on_purchase.delete_ineligible_user_assignments_in_batches!(batch_size: 1)

        expect(result).to eq(2)
      end

      it 'expires the cache keys for the ineligible users', :use_clean_rails_redis_caching do
        eligible_user_cache_key = eligible_user.duo_pro_cache_key_formatted
        ineligible_user_cache_key = ineligible_user.duo_pro_cache_key_formatted
        Rails.cache.write(eligible_user_cache_key, true, expires_in: 1.hour)
        Rails.cache.write(ineligible_user_cache_key, true, expires_in: 1.hour)

        add_on_purchase.namespace.add_guest(eligible_user)

        expect(add_on_purchase.reload.assigned_users.count).to eq(2)

        expect { expect(result).to eq(1) }
          .to change { add_on_purchase.reload.assigned_users.count }.by(-1)
          .and change { Rails.cache.read(ineligible_user_cache_key) }.from(true).to(nil)
          .and not_change { Rails.cache.read(eligible_user_cache_key) }
      end

      context 'when the add_on_purchase has no namespace' do
        before do
          add_on_purchase.update_attribute(:namespace, nil)
        end

        context 'when all assigned users are eligible' do
          it { is_expected.to eq(0) }
        end

        context 'when there are ineligible users' do
          it 'removes only ineligible user assignments' do
            ineligible_user.block!

            expect(add_on_purchase.reload.assigned_users.count).to eq(2)

            expect_next_instance_of(::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder) do |finder|
              expect(finder).to receive(:execute).and_call_original
            end

            expect do
              expect(result).to eq(1)
            end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

            expect(add_on_purchase.reload.assigned_users.where(user: eligible_user).count).to eq(1)
          end
        end
      end
    end

    context 'with no assigned_users records' do
      it { is_expected.to eq(0) }

      context 'when add_on_purchase does not have namespace' do
        before do
          add_on_purchase.update!(namespace: nil)
        end

        it { is_expected.to eq(0) }
      end
    end
  end

  describe "#lock_key_for_refreshing_user_assignments" do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    it 'returns lock key based on class name and id' do
      lock_key = "gitlab_subscriptions/add_on_purchase:user_refresh:#{add_on_purchase.id}"

      expect(add_on_purchase.lock_key_for_refreshing_user_assignments).to eq(lock_key)
    end
  end

  describe '#normalized_add_on_name' do
    context 'when add_on_name is code_suggestions' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, name: 'code_suggestions') }
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }

      it 'returns duo_pro' do
        expect(add_on_purchase.normalized_add_on_name).to eq('duo_pro')
      end
    end

    context 'when add_on_name is not mapped' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, name: 'product_analytics') }
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }

      it 'returns the original add_on_name' do
        expect(add_on_purchase.normalized_add_on_name).to eq('product_analytics')
      end
    end
  end

  describe '#destroy' do
    it_behaves_like 'create audits for user add-on assignments' do
      let(:entity) { add_on_purchase }
    end
  end
end
