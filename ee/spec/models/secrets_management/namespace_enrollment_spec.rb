# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::NamespaceEnrollment, feature_category: :secrets_management do
  subject(:enrollment) { build(:secrets_manager_namespace_enrollment) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'defaults' do
    it 'marks new records as beta' do
      expect(create(:secrets_manager_namespace_enrollment).beta).to be true
    end
  end

  describe 'scopes' do
    describe '.for_namespace' do
      let_it_be(:group) { create(:group) }
      let_it_be(:other_group) { create(:group) }
      let_it_be(:enrollment) { create(:secrets_manager_namespace_enrollment, namespace: group) }
      let_it_be(:other_enrollment) { create(:secrets_manager_namespace_enrollment, namespace: other_group) }

      it 'returns enrollments for the given namespace' do
        expect(described_class.for_namespace(group)).to contain_exactly(enrollment)
      end
    end
  end

  describe '.enrolled?' do
    let_it_be(:group) { create(:group) }

    context 'when namespace is enrolled' do
      before do
        create(:secrets_manager_namespace_enrollment, namespace: group)
      end

      it 'returns true' do
        expect(described_class.enrolled?(group)).to be true
      end
    end

    context 'when namespace is not enrolled' do
      it 'returns false' do
        expect(described_class.enrolled?(group)).to be false
      end
    end

    context 'when a different namespace is enrolled' do
      before do
        create(:secrets_manager_namespace_enrollment, namespace: create(:group))
      end

      it 'returns false' do
        expect(described_class.enrolled?(group)).to be false
      end
    end

    it 'checks the root ancestor' do
      subgroup = create(:group, parent: group)
      create(:secrets_manager_namespace_enrollment, namespace: group)

      expect(described_class.enrolled?(subgroup)).to be true
    end
  end

  describe '.beta_enrolled?' do
    let_it_be(:group) { create(:group) }

    context 'when the namespace has a beta enrollment' do
      before do
        create(:secrets_manager_namespace_enrollment, namespace: group, beta: true)
      end

      it 'returns true' do
        expect(described_class.beta_enrolled?(group)).to be true
      end

      it 'checks the root ancestor' do
        subgroup = create(:group, parent: group)

        expect(described_class.beta_enrolled?(subgroup)).to be true
      end
    end

    context 'when the enrollment is not beta' do
      before do
        create(:secrets_manager_namespace_enrollment, namespace: group, beta: false)
      end

      it 'returns false' do
        expect(described_class.beta_enrolled?(group)).to be false
      end
    end

    context 'when namespace is not enrolled' do
      it 'returns false' do
        expect(described_class.beta_enrolled?(group)).to be false
      end
    end
  end

  describe '.enrollment_allowed?' do
    let_it_be(:group) { create(:group) }

    context 'when on GitLab.com', :saas do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      it 'returns true for a root namespace' do
        expect(described_class.enrollment_allowed?(group)).to be true
      end

      context 'when namespace is not root' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        it 'returns false' do
          expect(described_class.enrollment_allowed?(subgroup)).to be false
        end
      end

      context 'when namespace is a user namespace' do
        let_it_be(:user_namespace) { create(:user_namespace) }

        it 'returns false' do
          expect(described_class.enrollment_allowed?(user_namespace)).to be false
        end
      end

      context 'when the namespace_enrollment feature flag is enabled only on the root_ancestor' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        before do
          stub_feature_flags(secrets_manager_namespace_enrollment: false)
          stub_feature_flags(secrets_manager_namespace_enrollment: group)
        end

        it 'still returns false for non-root namespaces' do
          expect(described_class.enrollment_allowed?(subgroup)).to be false
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_namespace_enrollment: false)
        end

        it 'returns false' do
          expect(described_class.enrollment_allowed?(group)).to be false
        end
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it 'returns false' do
          expect(described_class.enrollment_allowed?(group)).to be false
        end
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      it 'returns false' do
        expect(described_class.enrollment_allowed?(group)).to be false
      end
    end
  end

  describe 'uniqueness constraint' do
    let_it_be(:group) { create(:group) }

    it 'prevents duplicate enrollments via the unique DB index' do
      create(:secrets_manager_namespace_enrollment, namespace: group)

      expect { create(:secrets_manager_namespace_enrollment, namespace: group) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
