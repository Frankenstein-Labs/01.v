# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSettings::UpdateService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be_with_reload(:feature_setting) { create(:ai_feature_setting, provider: :vendored) }

  let(:params) { { provider: :self_hosted, self_hosted_model: self_hosted_model } }

  subject(:service_result) { described_class.new(feature_setting, user, params).execute }

  describe '#execute' do
    let(:audit_event) do
      {
        name: 'self_hosted_model_feature_changed',
        author: user,
        scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
        target: feature_setting,
        message: "Feature code_generations changed to Self-hosted model (mistral-7b-ollama-api)"
      }
    end

    it 'returns a success response' do
      expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)
      expect { service_result }.to change { feature_setting.reload.provider }.to("self_hosted")

      expect(service_result).to be_success
      expect(service_result.payload).to eq(feature_setting)
    end

    context 'for internal events' do
      context 'when transitioning from self_hosted to vendored' do
        let_it_be_with_reload(:feature_setting) do
          create(:ai_feature_setting,
            provider: :self_hosted,
            self_hosted_model: self_hosted_model,
            feature: :duo_chat
          )
        end

        let(:params) { { provider: :vendored } }

        it 'tracks the transition event' do
          expect { described_class.new(feature_setting, user, params).execute }
            .to trigger_internal_events('update_self_hosted_ai_feature_to_vendored_model')
                  .with(
                    user: user,
                    additional_properties: {
                      label: 'gitlab_default',
                      property: feature_setting.feature
                    }
                  )
        end
      end

      context 'when transitioning from disabled to vendored' do
        let_it_be_with_reload(:feature_setting) do
          create(:ai_feature_setting, provider: :disabled, feature: :duo_chat)
        end

        let(:params) { { provider: :vendored } }

        it 'tracks the transition event' do
          expect { described_class.new(feature_setting, user, params).execute }
            .to trigger_internal_events('update_self_hosted_ai_feature_to_vendored_model')
                  .with(
                    user: user,
                    additional_properties: {
                      label: 'gitlab_default',
                      property: feature_setting.feature
                    }
                  )
        end
      end

      context 'when already vendored' do
        let_it_be_with_reload(:feature_setting) do
          create(:ai_feature_setting, provider: :vendored, feature: :duo_chat)
        end

        let(:params) { { provider: :vendored } }

        it 'does not track the transition event' do
          expect { described_class.new(feature_setting, user, params).execute }
            .not_to trigger_internal_events('update_self_hosted_ai_feature_to_vendored_model')
        end
      end

      context 'when transitioning from vendored to another provider' do
        let_it_be_with_reload(:feature_setting) do
          create(:ai_feature_setting, provider: :vendored, feature: :duo_chat)
        end

        let(:params) { { provider: :self_hosted, self_hosted_model: self_hosted_model } }

        it 'does not track the transition event' do
          expect { described_class.new(feature_setting, user, params).execute }
            .not_to trigger_internal_events('update_self_hosted_ai_feature_to_vendored_model')
        end
      end

      context 'with new feature setting' do
        let(:feature_setting) { build(:ai_feature_setting, provider: :vendored, feature: :duo_chat) }

        it 'does not track the transition event for new records' do
          expect { described_class.new(feature_setting, user, params).execute }
            .not_to trigger_internal_events('update_self_hosted_ai_feature_to_vendored_model')
        end
      end
    end

    context 'when update fails' do
      let(:params) { { provider: '' } }

      it 'returns an error response' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        expect(service_result).to be_error
        expect(service_result.message).to include("Provider can't be blank")
      end
    end
  end
end
