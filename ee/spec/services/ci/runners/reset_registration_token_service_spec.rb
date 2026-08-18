# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::ResetRegistrationTokenService, '#execute', feature_category: :runner_core do
  subject(:execute) { described_class.new(scope, current_user).execute }

  let_it_be(:user) { build(:user) }
  let_it_be(:admin_user) { create(:user, :admin) }

  let(:expected_audit_scope) { scope }

  shared_examples 'a registration token reset operation' do
    context 'without user' do
      let(:current_user) { nil }

      it 'does not audit and returns error response', :aggregate_failures do
        expect(scope).not_to receive(token_reset_method_name)
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        is_expected.to be_error
      end
    end

    context 'with unauthorized user' do
      let(:current_user) { user }

      it 'does not audit and returns error response', :aggregate_failures do
        expect(scope).not_to receive(token_reset_method_name)
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        is_expected.to be_error
      end
    end

    context 'with admin user', :enable_admin_mode do
      let(:current_user) { admin_user }

      it 'calls audit on Auditor and returns the new token', :aggregate_failures do
        expect(scope).to receive(token_reset_method_name) do
          expect(scope).to receive(token_method_name).and_return("new #{scope.class.name} token value")
          true
        end.once

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          name: 'ci_runner_token_reset',
          author: current_user,
          scope: expected_audit_scope,
          target: an_instance_of(::Gitlab::Audit::NullTarget),
          message: "Reset #{scope_name} runner registration token",
          additional_details: expected_audit_details
        })

        expect(execute).to be_success
        expect(execute.payload[:new_registration_token]).to eq("new #{scope.class.name} token value")
      end

      context 'when allow_runner_registration_token is false' do
        before do
          stub_application_setting(allow_runner_registration_token: false)
        end

        it 'does not log an audit event and returns an error' do
          expect(scope).not_to receive(token_reset_method_name)
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          expect(execute).to be_error
        end
      end
    end
  end

  context 'with instance scope' do
    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:scope, freeze: false) { build(:application_setting) }
    let_it_be(:scope_name) { 'instance' }
    let(:expected_audit_scope) { an_instance_of(Gitlab::Audit::InstanceScope) }

    before do
      allow(ApplicationSetting).to receive(:current).and_return(scope)
      allow(ApplicationSetting).to receive(:current_without_cache).and_return(scope)
    end

    it_behaves_like 'a registration token reset operation' do
      let(:token_method_name) { :runners_registration_token }
      let(:token_reset_method_name) { :reset_runners_registration_token! }
      let(:expected_audit_details) do
        { from: scope.runners_registration_token[0...8], to: "new #{scope.class.name} token value"[0...8] }
      end
    end
  end

  context 'with group scope' do
    let_it_be(:scope, freeze: false) { create(:group, :allow_runner_registration_token) }
    let_it_be(:scope_name) { 'group' }

    it_behaves_like 'a registration token reset operation' do
      let(:token_method_name) { :runners_token }
      let(:token_reset_method_name) { :reset_runners_token! }
      let(:expected_audit_details) do
        {
          from: scope.runners_token[0...(8 + ::RunnersTokenPrefixable::RUNNERS_TOKEN_PREFIX.length)],
          to: "new #{scope.class.name} token value"[0...8]
        }
      end
    end
  end

  context 'with project scope' do
    let_it_be(:scope, freeze: false) { create(:project, :allow_runner_registration_token) }
    let_it_be(:scope_name) { 'project' }

    it_behaves_like 'a registration token reset operation' do
      let(:token_method_name) { :runners_token }
      let(:token_reset_method_name) { :reset_runners_token! }
      let(:expected_audit_details) do
        {
          from: scope.runners_token[0...(8 + ::RunnersTokenPrefixable::RUNNERS_TOKEN_PREFIX.length)],
          to: "new #{scope.class.name} token value"[0...8]
        }
      end
    end
  end
end
