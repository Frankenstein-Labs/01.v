# frozen_string_literal: true

RSpec.shared_examples 'a secrets manager entitlement gate' do
  describe 'entitlement gate' do
    subject(:result) { service.execute }

    # Only Initialize specs define `provision_worker_class`; Provision specs have no
    # analogous async worker, so the enqueue assertion below is skipped for them.
    let(:worker_spy) { class_spy(provision_worker_class) }

    before do
      stub_const(provision_worker_class.name, worker_spy) if respond_to?(:provision_worker_class)
    end

    context 'when secrets_manager_paid_experience is disabled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: false)
        allow(SecretsManagement::Entitlement).to receive(:for)
      end

      it 'does not consult the entitlement resolver' do
        result

        expect(SecretsManagement::Entitlement).not_to have_received(:for)
      end
    end

    context 'when secrets_manager_paid_experience is enabled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
      end

      {
        trial_eligible: false,
        trial: true,
        paid: true,
        offline_paid: true,
        blocked: false,
        ineligible: false
      }.each do |state, permits_writes|
        context "when the entitlement state is #{state}" do
          let(:blocked_reason) { state == :blocked ? :grace : nil }
          let(:entitlement) do
            SecretsManagement::Entitlement.new(state: state, blocked_reason: blocked_reason)
          end

          before do
            allow(SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
          end

          if permits_writes
            it 'proceeds as normal' do
              expect(result).to be_success
            end
          else
            it 'rejects with an entitlement_blocked error', :aggregate_failures do
              expect(result).to be_error
              expect(result.message).to eq("Secrets Manager cannot be #{gated_action}: entitlement state is #{state}")
              expect(result.reason).to eq(:entitlement_blocked)
              expect(result.payload).to eq(state: state, blocked_reason: blocked_reason)
              expect(worker_spy).not_to have_received(:perform_async) if respond_to?(:provision_worker_class)
            end

            it 'logs the rejection' do
              expect(Gitlab::AppLogger).to receive(:info).with(
                hash_including(
                  message: 'Secrets Manager entitlement gate rejected write',
                  entitlement_state: state,
                  entitlement_blocked_reason: blocked_reason
                )
              )

              result
            end

            it 'emits denial telemetry' do
              expect(::SecretsManagement::Entitlement::DenialTelemetry)
                .to receive(:track).with(hash_including(entitlement: entitlement, surface: :service_gate))

              result
            end
          end
        end
      end
    end
  end
end
