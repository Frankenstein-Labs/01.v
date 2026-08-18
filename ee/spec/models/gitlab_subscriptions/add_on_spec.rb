# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOn, feature_category: :subscription_management do
  subject { build(:gitlab_subscription_add_on) }

  describe 'associations' do
    it { is_expected.to have_many(:add_on_purchases).with_foreign_key(:subscription_add_on_id).inverse_of(:add_on) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).ignoring_case_sensitivity }

    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:description).is_at_most(512) }
  end

  describe 'scopes' do
    let_it_be(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let_it_be(:duo_amazon_q_add_on) { create(:gitlab_subscription_add_on, :duo_amazon_q) }
    let_it_be(:self_hosted_dap_add_on) { create(:gitlab_subscription_add_on, :self_hosted_dap) }
    let_it_be(:gitlab_credits_add_on) { create(:gitlab_subscription_add_on, :gitlab_credits) }
    let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

    describe '.duo_add_ons' do
      subject(:duo_add_ons) { described_class.duo_add_ons }

      it 'only queries the duo add-ons' do
        expect(duo_add_ons)
          .to contain_exactly(
            duo_core_add_on,
            duo_pro_add_on,
            duo_enterprise_add_on,
            duo_amazon_q_add_on,
            self_hosted_dap_add_on,
            gitlab_credits_add_on
          )
      end
    end

    describe '.seat_assignable_duo_add_ons' do
      subject(:seat_assignable_duo_add_ons) { described_class.seat_assignable_duo_add_ons }

      it 'only queries the duo add-ons with seat assignments' do
        expect(seat_assignable_duo_add_ons)
          .to contain_exactly(duo_pro_add_on, duo_enterprise_add_on)
      end
    end

    describe '.active' do
      let_it_be(:group_1) { create(:group) }
      let_it_be(:group_2) { create(:group) }
      let_it_be(:active_pro_add_on_for_gitlab_com) { duo_pro_add_on }
      let_it_be(:active_q_add_on_for_gitlab_com) { duo_amazon_q_add_on }
      let_it_be(:active_add_on_for_self_managed) { duo_enterprise_add_on }

      before_all do
        create(:gitlab_subscription_add_on_purchase, :active,
          add_on: active_pro_add_on_for_gitlab_com, namespace: group_1)
        create(:gitlab_subscription_add_on_purchase, :active,
          add_on: active_q_add_on_for_gitlab_com, namespace: group_2)
        create(:gitlab_subscription_add_on_purchase, :active, :self_managed,
          add_on: active_add_on_for_self_managed)
        create(:gitlab_subscription_add_on_purchase, :expired,
          add_on: duo_core_add_on, namespace: group_1)
        create(:gitlab_subscription_add_on_purchase, :expired, :self_managed,
          add_on: product_analytics_add_on)
      end

      context 'when several group IDs are provided' do
        let(:group_ids) { [group_1.id, group_2.id] }

        subject(:active_add_ons) { described_class.active(group_ids) }

        it 'returns add-ons filtered by active purchases for gitlab.com' do
          expect(active_add_ons.map(&:id)).to contain_exactly(
            active_pro_add_on_for_gitlab_com.id,
            active_q_add_on_for_gitlab_com.id
          )
        end
      end

      context 'when one group ID is provided' do
        let(:group_ids) { [group_2.id] }

        subject(:active_add_ons) { described_class.active(group_ids) }

        it 'returns add-ons filtered by active purchases for gitlab.com' do
          expect(active_add_ons.map(&:id)).to contain_exactly(
            active_q_add_on_for_gitlab_com.id
          )
        end
      end

      context 'when nil is provided' do
        let(:group_ids) { nil }

        subject(:active_add_ons) { described_class.active(group_ids) }

        it 'returns add-ons with active purchases for self-managed' do
          expect(active_add_ons.map(&:id)).to contain_exactly(
            active_add_on_for_self_managed.id
          )
        end
      end

      context 'when empty group IDs array is provided' do
        let(:group_ids) { [] }

        subject(:active_add_ons) { described_class.active(group_ids) }

        it 'returns add-ons with active purchases for self-managed' do
          expect(active_add_ons.map(&:id)).to contain_exactly(
            active_add_on_for_self_managed.id
          )
        end
      end

      context 'when no group IDs are provided' do
        subject(:active_add_ons) { described_class.active }

        it 'returns all active add-ons with active purchases for self-managed' do
          expect(active_add_ons.map(&:id)).to contain_exactly(
            active_add_on_for_self_managed.id
          )
        end
      end
    end
  end

  describe '.descriptions' do
    subject(:descriptions) { described_class.descriptions }

    it 'returns a description for each defined add-on' do
      expect(descriptions.stringify_keys.keys).to eq(described_class.names.keys)
      expect(descriptions.values.all?(&:present?)).to be(true)
    end
  end

  describe '.uids_for_names' do
    it 'maps a single add-on name to its uid' do
      expect(described_class.uids_for_names(:code_suggestions)).to eq([1])
    end

    it 'maps a mix of symbol and string names to their uids' do
      expect(described_class.uids_for_names([:code_suggestions, 'duo_enterprise'])).to match_array([1, 3])
    end

    it 'drops unknown names' do
      expect(described_class.uids_for_names(%w[code_suggestions foo-bar])).to eq([1])
    end

    it 'returns an empty array for an unknown name' do
      expect(described_class.uids_for_names('foo-bar')).to eq([])
    end

    it 'returns an empty array for empty input' do
      expect(described_class.uids_for_names([])).to eq([])
    end
  end

  describe '.find_or_create_by_name' do
    subject(:find_or_create_by_name) { described_class.find_or_create_by_name(add_on_name) }

    let(:add_on_name) { :code_suggestions }

    context 'when a record was found' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

      it 'returns the found add-on' do
        expect(find_or_create_by_name).to eq(add_on)
      end

      it 'does not create a new record' do
        expect { find_or_create_by_name }.not_to change { described_class.count }
      end
    end

    context 'with product_analytics add-on' do
      let(:add_on_name) { 'product_analytics' }

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(product_analytics_billing: false)
        end

        it 'raises an ArgumentError' do
          expect { find_or_create_by_name }.to raise_error(ArgumentError)
        end
      end

      context 'when feature flag is enabled' do
        before do
          stub_feature_flags(product_analytics_billing: true)
        end

        it 'creates a new record' do
          expect { find_or_create_by_name }.to change { described_class.count }.by(1)
        end
      end
    end

    it 'creates a new record with the correct description' do
      add_on = find_or_create_by_name

      expect(add_on).to be_an_instance_of(described_class)
      expect(add_on).to have_attributes(
        name: add_on_name.to_s,
        description: described_class.descriptions[add_on_name]
      )
    end
  end

  describe '#seat_assignable?' do
    using RSpec::Parameterized::TableSyntax

    where(:add_on_name, :result) do
      'code_suggestions'  | true
      'product_analytics' | false
      'duo_enterprise'    | true
      'duo_amazon_q'      | false
      'duo_core'          | false
      'self_hosted_dap'   | false
      'gitlab_credits'    | false
      'secrets_manager'   | false
    end

    with_them do
      it 'returns correct value for different add-ons' do
        add_on = described_class.new(name: add_on_name)

        expect(add_on.seat_assignable?).to eq(result)
      end
    end
  end
end
