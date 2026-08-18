# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Tag, feature_category: :container_registry do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:repository) { create(:container_repository, name: '', project: project) }

  let(:tag) { described_class.new(repository, 'sample') }

  before do
    stub_licensed_features(container_registry_immutable_tag_rules: true)
  end

  describe '#protection_rule' do
    subject { tag.protection_rule }

    context 'when there are matching immutable rules' do
      before_all do
        create(
          :container_registry_protection_tag_rule,
          :immutable,
          project: project,
          tag_name_pattern: 'sample'
        )

        create(
          :container_registry_protection_tag_rule,
          project: project,
          tag_name_pattern: '.*',
          minimum_access_level_for_push: ::Gitlab::Access::MAINTAINER,
          minimum_access_level_for_delete: ::Gitlab::Access::OWNER
        )
      end

      it 'returns a matching immutable rule' do
        is_expected.to have_attributes(
          tag_name_pattern: 'sample',
          minimum_access_level_for_push: nil,
          minimum_access_level_for_delete: nil
        )
      end

      context 'when the feature is unlicensed' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it 'does not return a matching immutable rule' do
          is_expected.to have_attributes(
            minimum_access_level_for_push: 'maintainer',
            minimum_access_level_for_delete: 'owner'
          )
        end
      end
    end
  end

  describe '#protected_for_delete?' do
    subject { tag.protected_for_delete?(build(:user)) }

    context 'when there is an immutable tag rule' do
      before_all do
        create(
          :container_registry_protection_tag_rule,
          :immutable,
          project: project,
          tag_name_pattern: 'sample'
        )
      end

      it { is_expected.to be_truthy }

      context 'when the feature is unlicensed' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it { is_expected.to be_falsey }
      end
    end
  end
end
