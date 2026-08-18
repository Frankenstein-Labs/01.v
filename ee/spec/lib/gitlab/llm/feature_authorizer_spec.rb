# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::FeatureAuthorizer, feature_category: :ai_abstraction_layer do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:feature_name) { :summarize_review }
  let(:instance) do
    described_class.new(
      container: group,
      feature_name: feature_name,
      user: user
    )
  end

  subject(:allowed?) { instance.allowed? }

  describe '#allowed?' do
    before do
      allow(user).to receive(:allowed_to_use?)
        .with(feature_name, licensed_feature: :ai_features, root_namespace: group.root_ancestor)
        .and_return(true)
    end

    context 'when container has correct setting and license' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
      end

      context 'when ai_global_switch is turned off' do
        before do
          stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature_name => { self_managed: false })
        end

        it 'returns false' do
          stub_feature_flags(ai_global_switch: false)

          expect(allowed?).to be false
        end
      end

      context 'when duo features are disabled on container' do
        it 'returns false' do
          group.namespace_settings.update!(duo_features_enabled: false)

          expect(allowed?).to be false
        end
      end
    end

    context 'when user is not allowed to use feature' do
      before do
        allow(user).to receive(:allowed_to_use?)
          .with(feature_name, licensed_feature: :ai_features, root_namespace: group.root_ancestor)
          .and_return(false)
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when container does not have correct license' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when container is not present' do
      let(:instance) do
        described_class.new(
          container: nil,
          feature_name: feature_name,
          user: user
        )
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when user is not present' do
      let(:instance) do
        described_class.new(
          container: group,
          feature_name: feature_name,
          user: nil
        )
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when using custom licensed feature values' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
        group.namespace_settings.update!(duo_features_enabled: true)
      end

      context 'when custom licensed_feature is specified' do
        let(:instance) do
          described_class.new(
            container: group,
            feature_name: feature_name,
            user: user,
            licensed_feature: :custom_feature
          )
        end

        it 'uses the specified licensed_feature' do
          expect(user).to receive(:allowed_to_use?).with(
            feature_name,
            licensed_feature: :custom_feature,
            root_namespace: group.root_ancestor
          ).and_return(true)
          expect(allowed?).to be true
        end
      end
    end

    context 'when verifying root_namespace parameter is passed correctly' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
        group.namespace_settings.update!(duo_features_enabled: true)
      end

      it 'calls allowed_to_use? with root_namespace from container.root_ancestor' do
        expect(user).to receive(:allowed_to_use?).with(
          feature_name,
          licensed_feature: :ai_features,
          root_namespace: group.root_ancestor
        ).and_return(true)

        expect(allowed?).to be true
      end

      context 'with nested group' do
        let(:subgroup) { create(:group, parent: group) }
        let(:instance) do
          described_class.new(
            container: subgroup,
            feature_name: feature_name,
            user: user
          )
        end

        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
          subgroup.namespace_settings.update!(duo_features_enabled: true)
        end

        it 'uses root_ancestor of the container' do
          expect(user).to receive(:allowed_to_use?).with(
            feature_name,
            licensed_feature: :ai_features,
            root_namespace: subgroup.root_ancestor
          ).and_return(true)

          expect(allowed?).to be true
        end
      end
    end
  end
end
