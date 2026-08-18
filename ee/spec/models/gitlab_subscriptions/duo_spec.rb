# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo, feature_category: :"add-on_provisioning" do
  using RSpec::Parameterized::TableSyntax

  describe '.todo_message' do
    it 'returns a message about AI-native features' do
      message = described_class.todo_message

      expect(message).to include(s_('Todos|You now have access to AI-native features.'))
    end
  end

  describe '.enterprise_or_pro_for_namespace' do
    subject { described_class.enterprise_or_pro_for_namespace(namespace) }

    let(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let(:expires_on) { 1.year.from_now.to_date }
    let(:namespace) { create(:namespace) }

    let!(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace, expires_on: expires_on)
    end

    it { is_expected.to eq(add_on_purchase) }

    context 'with expired add-on purchase' do
      let(:expires_on) { 1.day.ago.to_date }

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'with different namespace' do
      subject { described_class.enterprise_or_pro_for_namespace("foo") }

      it { is_expected.to be_nil }
    end

    context 'with other duo add-on' do
      let(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'with multiple duo add-ons' do
      let(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      let!(:duo_enterprise_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: duo_enterprise_add_on,
          namespace: namespace,
          expires_on: expires_on
        )
      end

      it { is_expected.to eq(duo_enterprise_add_on_purchase) }
    end

    context 'with non Duo add-on' do
      let(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      it { is_expected.to be_nil }
    end
  end

  describe '.no_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    subject { described_class.no_add_on_purchase_for_namespace?(namespace) }

    it { is_expected.to be(true) }

    context 'with active add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }

      context 'with different namespace' do
        subject { described_class.no_add_on_purchase_for_namespace?('foo') }

        it { is_expected.to be(true) }
      end
    end

    context 'with expired add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :expired, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with active trial add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :active_trial, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with expired trial add-on purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :expired_trial, add_on: add_on, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with other duo add-on' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'with non Duo add-on' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.any_add_on_purchase_for_namespace' do
    let_it_be(:namespace) { create(:namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when the enterprise add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when there is a pro add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when the pro add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace: namespace)
      end

      it 'returns the add-on purchase' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace).id).to eq(add_on_purchase.id)
      end
    end

    context 'when there is no add-on purchase for the namespace' do
      it 'returns nil' do
        expect(described_class.any_add_on_purchase_for_namespace(namespace)).to be_nil
      end
    end
  end

  describe '.any_active_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.any_active_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when there is a pro add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(false) }
    end
  end

  describe '.active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap?' do
    let!(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        namespace: namespace,
        add_on: add_on,
        started_at: started_at,
        expires_on: expires_on
      )
    end

    let(:started_at) { 1.day.ago.to_date }
    let(:expires_on) { 1.year.from_now.to_date }
    let(:namespace) { nil } # self-managed
    let(:add_on) { build(:gitlab_subscription_add_on, :duo_core) }

    it { expect(described_class).to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }

    context 'with Duo Pro' do
      let(:add_on) { build(:gitlab_subscription_add_on, :duo_pro) }

      it { expect(described_class).to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }
    end

    context 'with Duo Enterprise' do
      let(:add_on) { build(:gitlab_subscription_add_on, :duo_enterprise) }

      it { expect(described_class).to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }
    end

    context 'with self-hosted DAP' do
      let(:add_on) { build(:gitlab_subscription_add_on, :self_hosted_dap) }

      it { expect(described_class).to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }
    end

    context 'with other add-on' do
      let(:add_on) { build(:gitlab_subscription_add_on, :duo_amazon_q) }

      it { expect(described_class).not_to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }
    end

    context 'with inactive add-on' do
      let(:started_at) { 1.year.ago.to_date }
      let(:expires_on) { 1.month.ago.to_date }

      it { expect(described_class).not_to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }
    end

    context 'with GitLab.com add-on' do
      let(:namespace) { build(:namespace) }

      it { expect(described_class).not_to be_active_self_managed_duo_core_pro_enterprise_or_self_hosted_dap }
    end
  end

  describe '.active_self_managed_gitlab_credits?' do
    subject { described_class.active_self_managed_gitlab_credits? }

    context 'with active self-managed gitlab_credits add-on' do
      let!(:add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          :gitlab_credits,
          namespace: nil,
          started_at: 1.day.ago.to_date,
          expires_on: 1.year.from_now.to_date
        )
      end

      it { is_expected.to be(true) }

      it 'caches the result in SafeRequestStore', :request_store do
        expect(GitlabSubscriptions::AddOnPurchase).to receive(:for_gitlab_credits).once.and_call_original

        described_class.active_self_managed_gitlab_credits?
        described_class.active_self_managed_gitlab_credits?
      end
    end

    context 'with expired self-managed gitlab_credits add-on' do
      let!(:add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          :gitlab_credits,
          namespace: nil,
          started_at: 1.year.ago.to_date,
          expires_on: 1.month.ago.to_date
        )
      end

      it { is_expected.to be(false) }
    end

    context 'with GitLab.com gitlab_credits add-on' do
      let!(:add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          :gitlab_credits,
          namespace: build(:namespace)
        )
      end

      it { is_expected.to be(false) }
    end

    context 'with no gitlab_credits add-on' do
      it { is_expected.to be(false) }
    end
  end

  describe '.duo_settings_available?' do
    let(:namespace) { create(:group) }

    subject { described_class.duo_settings_available?(namespace) }

    context 'with GitLab.com add-on' do
      where(:add_on, :expected) do
        :code_suggestions  | true
        :duo_core          | true
        :duo_enterprise    | true
      end

      with_them do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          create(:gitlab_subscription_add_on_purchase, add_on, namespace: namespace)
        end

        it { is_expected.to be(expected) }
      end
    end

    context 'with self-managed add-on' do
      where(:add_on, :expected) do
        :code_suggestions  | true
        :duo_core          | true
        :duo_enterprise    | true
        :self_hosted_dap   | true
        :duo_amazon_q      | false
      end

      with_them do
        before do
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on)
        end

        it { is_expected.to be(expected) }
      end
    end

    context 'with self-managed gitlab_credits add-on' do
      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :self_managed,
          organization: namespace.organization)
      end

      it { is_expected.to be(true) }
    end

    context 'with SaaS namespace-level gitlab_credits add-on', :saas do
      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    it 'returns false with no add-on' do
      is_expected.to be(false)
    end
  end

  describe '.active_self_managed_duo_pro_or_enterprise' do
    subject(:result) { described_class.active_self_managed_duo_pro_or_enterprise }

    let!(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        namespace: namespace,
        add_on: add_on,
        started_at: started_at,
        expires_on: expires_on
      )
    end

    let(:started_at) { 1.day.ago.to_date }
    let(:expires_on) { 1.year.from_now.to_date }
    let(:namespace) { nil } # self-managed
    let(:add_on) { build(:gitlab_subscription_add_on, :duo_pro) }

    it { expect(result).to eq add_on_purchase }

    context 'with Duo Enterprise' do
      let(:add_on) { build(:gitlab_subscription_add_on, :duo_enterprise) }

      it { expect(result).to eq add_on_purchase }
    end

    context 'with other add-on' do
      let(:add_on) { build(:gitlab_subscription_add_on, :duo_core) }

      it { expect(result).not_to eq add_on_purchase }
    end

    context 'with inactive add-on' do
      let(:started_at) { 1.year.ago.to_date }
      let(:expires_on) { 1.month.ago.to_date }

      it { expect(result).not_to eq add_on_purchase }
    end

    context 'with GitLab.com add-on' do
      let(:namespace) { build(:namespace) }

      it { expect(result).not_to eq add_on_purchase }
    end
  end
end
