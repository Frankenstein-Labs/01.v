# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Vulnerabilities::FindingTokenStatusResolver, feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: 'secret_detection') }

  specify do
    expect(described_class)
      .to have_nullable_graphql_type(Types::Vulnerabilities::FindingTokenStatusType)
  end

  describe '#resolve' do
    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(secret_detection_validity_checks: true)
      project.security_setting.update!(validity_checks_enabled: true)
    end

    subject(:result) { resolve_status }

    shared_examples 'does not expose token status' do
      it { is_expected.to be_nil }
    end

    context 'when report_type is not secret_detection' do
      let(:vulnerability) { create(:vulnerability, project: project, report_type: 'sast') }

      it_behaves_like 'does not expose token status'
    end

    context 'when project is not licensed for secret_detection_validity_checks' do
      before do
        stub_licensed_features(secret_detection_validity_checks: false)
      end

      it_behaves_like 'does not expose token status'
    end

    context 'when project setting validity_checks_enabled is false' do
      before do
        project.security_setting.update!(validity_checks_enabled: false)
      end

      it_behaves_like 'does not expose token status'
    end

    context 'when the vulnerability has no finding' do
      it_behaves_like 'does not expose token status'
    end

    context 'when there is a finding but no token status record' do
      before do
        create(:vulnerabilities_finding, vulnerability: vulnerability)
      end

      it 'returns nil for .value' do
        expect(result.value).to be_nil
      end
    end

    context 'when a token status exists' do
      let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: 'secret_detection') }
      let_it_be(:finding) do
        create(
          :vulnerabilities_finding,
          :with_token_status,
          token_status: :active,
          vulnerability: vulnerability
        )
      end

      it 'returns the active status' do
        status = result.value
        expect(status).to be_a(Vulnerabilities::FindingTokenStatus)
        expect(status.status).to eq('active')
      end
    end

    context 'when multiple token status records exist for different findings' do
      let_it_be(:vulnerability1) { create(:vulnerability, project: project, report_type: 'secret_detection') }
      let_it_be(:vulnerability2) { create(:vulnerability, project: project, report_type: 'secret_detection') }

      let_it_be(:finding1) do
        create(
          :vulnerabilities_finding,
          :with_token_status,
          token_status: :active,
          vulnerability: vulnerability1
        )
      end

      let_it_be(:finding2) do
        create(
          :vulnerabilities_finding,
          :with_token_status,
          token_status: :inactive,
          vulnerability: vulnerability2
        )
      end

      it 'returns the correct token status for each vulnerability' do
        result1 = resolve_status(vulnerability1)
        result2 = resolve_status(vulnerability2)

        expect(result1.value.status).to eq('active')
        expect(result2.value.status).to eq('inactive')
      end
    end
  end

  def resolve_status(obj = vulnerability)
    resolve(
      described_class,
      obj: obj,
      ctx: { current_user: user },
      arg_style: :internal
    )
  end
end
