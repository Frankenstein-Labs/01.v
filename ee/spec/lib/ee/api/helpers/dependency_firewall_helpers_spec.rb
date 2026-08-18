# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Helpers::DependencyFirewallHelpers, feature_category: :dependency_firewall do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:helper, freeze: false) { Class.new.include(described_class).new }
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let(:pkg_type) { 'maven' }
  let(:name) { 'com.example/my-app' }
  let(:version) { '1.0.0' }
  let(:firewall_service) { Security::DependencyFirewall::EnforcementService }

  before do
    allow(firewall_service).to receive(:firewall_check)
      .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    allow(helper).to receive(:render_structured_api_error!)
    allow(helper).to receive(:current_user).and_return(current_user)
  end

  shared_examples 'dependency firewall enforcement' do |operation_constant|
    it 'calls firewall_check with the correct operation and current_user' do
      expect(firewall_service).to receive(:firewall_check)
        .with(
          project: project,
          pkg_type: pkg_type,
          name: name,
          version: version,
          operation: operation_constant,
          current_user: current_user
        )
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

      subject
    end

    context 'when the firewall blocks the package' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: 'GPL-3.0 is denied', reason: firewall_service::SUCCESS_BLOCKED))
      end

      it 'calls render_structured_api_error! with a policy violation message' do
        expect(helper).to receive(:render_structured_api_error!)
          .with({ message: 'GPL-3.0 is denied', error: 'Dependency Firewall policy violation' }, 403)

        subject
      end

      context 'when the block message is blank' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
        end

        it 'falls back to a default violation message' do
          expect(helper).to receive(:render_structured_api_error!)
            .with(
              { message: 'Dependency Firewall policy violation', error: 'Dependency Firewall policy violation' },
              403
            )

          subject
        end
      end
    end

    context 'when the firewall warns about the package' do
      let(:warning_message) { "Package 'com.example/my-app' violates 'License policy' policy" }
      let(:response_headers) { {} }

      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.success(
            payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
          ))
        allow(helper).to receive(:header).and_return(response_headers)
      end

      it 'does not render an error' do
        expect(helper).not_to receive(:render_structured_api_error!)

        subject
      end

      it 'sets the X-Gitlab-Dependency-Firewall-Warning header to the reason string' do
        subject

        expect(response_headers[described_class::WARNING_HEADER]).to eq(warning_message)
      end

      context 'when the warning message contains CR/LF characters' do
        let(:warning_message) { "Package 'x' violates 'p' policy\r\nX-Injected: bad" }

        it 'collapses CR/LF to a space to prevent header injection' do
          subject

          expect(response_headers[described_class::WARNING_HEADER])
            .to eq("Package 'x' violates 'p' policy X-Injected: bad")
        end
      end

      context 'when the warning message contains null bytes or other ASCII control characters' do
        let(:warning_message) { "Package 'x\x00\x01\x7F' violates 'p\x08\x1F' policy" }

        it 'strips RFC 7230-prohibited control characters from the header value' do
          subject

          expect(response_headers[described_class::WARNING_HEADER])
            .to eq("Package 'x' violates 'p' policy")
        end
      end

      context 'when the warning message is blank' do
        let(:warning_message) { '' }

        it 'does not set the warning header' do
          subject

          expect(response_headers).not_to have_key(described_class::WARNING_HEADER)
        end
      end

      context 'when the payload has no :message key' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_WARNING }))
        end

        it 'does not set the warning header' do
          subject

          expect(response_headers).not_to have_key(described_class::WARNING_HEADER)
        end
      end
    end

    context 'when firewall_check raises ArgumentError' do
      let(:error) { ArgumentError.new('DependencyFirewall: name is blank') }

      before do
        allow(firewall_service).to receive(:firewall_check).and_raise(error)
      end

      it 'raises the error' do
        expect { subject }.to raise_error(ArgumentError, 'DependencyFirewall: name is blank')
      end
    end

    context 'when firewall_check raises a non-ArgumentError exception' do
      it 'propagates as an unhandled error without logging' do
        allow(firewall_service).to receive(:firewall_check)
          .and_raise(ActiveRecord::StatementInvalid, 'db connection failed')

        expect(::Gitlab::AppLogger).not_to receive(:error)
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, 'db connection failed')
      end
    end
  end

  describe '#enforce_dependency_firewall!' do
    subject do
      helper.enforce_dependency_firewall!(
        project: project,
        pkg_type: pkg_type,
        name: name,
        version: version,
        operation: Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
      )
    end

    it_behaves_like 'dependency firewall enforcement',
      Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
  end
end
