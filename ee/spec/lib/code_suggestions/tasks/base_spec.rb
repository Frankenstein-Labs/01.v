# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::Base, feature_category: :code_suggestions do
  let(:klass) { ChildTaskClass }
  let(:user) { create(:user) }

  before do
    stub_const('ChildTaskClass',
      Class.new(described_class) do
        def model_details
          @model_details ||= CodeSuggestions::ModelDetails::Base.new(
            current_user: current_user,
            feature_setting_name: :code_generations,
            unit_primitive_name: :generate_code
          )
        end
      end
    )
  end

  describe '#initialization' do
    it 'raises Argument error' do
      # current user is a mandatory param
      expect { klass.new }.to raise_error(ArgumentError, 'missing keyword: :current_user')
    end
  end

  describe '#prompt_request_params' do
    it 'raises NotImplementedError' do
      expect { klass.new(current_user: user).prompt_request_params }.to raise_error(NotImplementedError)
    end
  end

  describe '#endpoint' do
    it 'raises NotImplementedError' do
      expect { klass.new(current_user: user).endpoint }.to raise_error(NotImplementedError)
    end
  end

  describe '#feature_disabled?' do
    subject(:feature_disabled?) { klass.new(current_user: user).feature_disabled? }

    it 'returns false' do
      expect(feature_disabled?).to be(false)
    end

    context 'when the feature is self-hosted' do
      include RSpec::Parameterized::TableSyntax

      where(:provider, :expected_result) do
        [
          [:self_hosted, false],
          [:vendored, false],
          [:disabled, true]
        ]
      end

      with_them do
        let!(:feature_setting) { create(:ai_feature_setting, provider: provider) }

        it 'returns the expected result' do
          expect(feature_disabled?).to eq(expected_result)
        end
      end
    end
  end

  describe '#vendored?' do
    subject(:vendored?) { klass.new(current_user: user).vendored? }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it 'returns false' do
      expect(vendored?).to be(false)
    end

    context 'when the feature is self-hosted' do
      include RSpec::Parameterized::TableSyntax

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      where(:provider, :expected_result) do
        [
          [:self_hosted, false],
          [:vendored, true],
          [:disabled, false]
        ]
      end

      with_them do
        let!(:feature_setting) { create(:ai_feature_setting, provider: provider) }

        it 'returns the expected result' do
          expect(vendored?).to eq(expected_result)
        end
      end
    end
  end
end
