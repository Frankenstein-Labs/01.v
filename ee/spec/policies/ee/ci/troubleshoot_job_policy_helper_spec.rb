# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Ci::TroubleshootJobPolicyHelper, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:build) { create(:ci_build, project: project) }

  let(:policy_class) do
    Class.new(Ci::BuildPolicy) do
      include EE::Ci::TroubleshootJobPolicyHelper
    end
  end

  subject(:policy) { policy_class.new(user, build) }

  describe 'troubleshoot_job_cloud_connector_authorized condition' do
    context 'when user is nil' do
      let(:user) { nil }

      it 'returns false' do
        expect(policy.troubleshoot_job_cloud_connector_authorized?).to be false
      end
    end

    context 'when user is present' do
      using RSpec::Parameterized::TableSyntax

      where(:authorizer_allowed, :expected_result) do
        true  | true
        false | false
      end

      with_them do
        before do
          allow(user).to receive(:allowed_to_use?).with(:troubleshoot_job).and_return(authorizer_allowed)
        end

        it 'returns the expected result' do
          expect(policy.troubleshoot_job_cloud_connector_authorized?).to be expected_result
        end
      end
    end
  end

  describe 'troubleshoot_job_with_ai_authorized condition' do
    using RSpec::Parameterized::TableSyntax

    where(:authorizer_allowed, :expected_result) do
      true  | true
      false | false
    end

    with_them do
      before do
        response = instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: authorizer_allowed)
        allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:resource)
          .with(resource: project, user: user)
          .and_return(response)
      end

      it 'returns the expected result' do
        expect(policy.troubleshoot_job_with_ai_authorized?).to be expected_result
      end
    end
  end

  describe 'troubleshoot_job_licensed condition' do
    using RSpec::Parameterized::TableSyntax

    where(:licensed, :expected_result) do
      true  | true
      false | false
    end

    with_them do
      before do
        stub_licensed_features(troubleshoot_job: licensed)
      end

      it 'returns the expected result' do
        expect(policy.troubleshoot_job_licensed?).to be expected_result
      end
    end
  end
end
