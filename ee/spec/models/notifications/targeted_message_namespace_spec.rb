# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessageNamespace, feature_category: :acquisition do
  describe 'associations' do
    it { is_expected.to belong_to(:targeted_message).required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    subject { build(:targeted_message_namespace) }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:targeted_message_id) }
  end

  describe 'scopes' do
    describe ".by_namespace_for_user" do
      let_it_be(:user_1) { create(:user) }
      let_it_be(:user_2) { create(:user) }

      let_it_be(:targeted_message_namespace_1) { create(:targeted_message_namespace) }
      let_it_be(:namespace_1) { targeted_message_namespace_1.namespace }
      let_it_be(:dismissal) do
        create(:targeted_message_dismissal, targeted_message_id: targeted_message_namespace_1.targeted_message_id,
          namespace: namespace_1, user: user_1)
      end

      let_it_be(:targeted_message_namespace_2) { create(:targeted_message_namespace) }
      let_it_be(:namespace_2) { targeted_message_namespace_2.namespace }

      it "returns records for the given namespace" do
        expect(described_class.by_namespace_for_user(namespace_1,
          user_2)).to contain_exactly(targeted_message_namespace_1)
      end

      it "skips records that have been dismissed" do
        expect(described_class.by_namespace_for_user(namespace_1, user_1)).to be_empty
      end

      it "returns records that have been dismissed by other users" do
        result = described_class.by_namespace_for_user(namespace_1, user_2)
        expect(result).to contain_exactly(targeted_message_namespace_1)
      end

      context 'when a message was dismissed in the namespace' do
        let_it_be(:targeted_message_namespace_2) do
          create(:targeted_message_namespace, namespace: namespace_1)
        end

        it 'returns other undismissed messages in namespace' do
          expect(described_class.by_namespace_for_user(namespace_1, user_1))
            .to contain_exactly(targeted_message_namespace_2)
        end
      end
    end
  end

  describe ".for_namespaces" do
    let_it_be(:targeted_message_namespace_1) { create(:targeted_message_namespace) }
    let_it_be(:targeted_message_namespace_2) { create(:targeted_message_namespace) }
    let_it_be(:targeted_message_namespace_3) { create(:targeted_message_namespace) }

    it "returns records for the given namespace ids" do
      namespace_ids = [targeted_message_namespace_1.namespace_id, targeted_message_namespace_2.namespace_id]
      expect(described_class.for_namespaces(namespace_ids))
        .to contain_exactly(targeted_message_namespace_1, targeted_message_namespace_2)
    end

    it "returns empty result when no matching namespace ids" do
      expect(described_class.for_namespaces([-1, -2])).to be_empty
    end
  end
end
