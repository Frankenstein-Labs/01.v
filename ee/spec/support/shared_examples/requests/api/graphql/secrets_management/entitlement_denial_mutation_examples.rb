# frozen_string_literal: true

# The including context must define:
# - post_mutation: the subject that posts the GraphQL mutation
# - mutation_response: the GraphQL mutation response hash
# - payload_key: camelCase GraphQL field name for the mutation's main payload (e.g. 'projectSecret')
# - service_class: the mutation's underlying service class, to assert it's never instantiated
# and must run inside a context where current_user is already authorized for the mutation, so the
# entitlement denial under test -- not a plain role/permission denial -- is what's exercised.
RSpec.shared_examples 'a secrets manager mutation blocked on entitlement' do
  before do
    stub_feature_flags(secrets_manager_paid_experience: true)
  end

  shared_examples 'a structured entitlement denial' do |reason|
    it "returns reason #{reason.to_s.upcase} and does not call the underlying service", :aggregate_failures do
      expect(service_class).not_to receive(:new)

      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response[payload_key]).to be_nil
      expect(mutation_response['errors'])
        .to include(SecretsManagement::EnforcesWriteEntitlement::WRITE_DENIAL_MESSAGE)
      expect(mutation_response['reason']).to eq(reason.to_s.upcase)
    end
  end

  context 'when the namespace is not eligible for Secrets Manager' do
    before do
      allow(SecretsManagement::Entitlement).to receive(:for)
        .and_return(SecretsManagement::Entitlement.new(state: :ineligible))
    end

    it_behaves_like 'a structured entitlement denial', :ineligible
  end

  context "when the namespace's trial has expired" do
    before do
      allow(SecretsManagement::Entitlement).to receive(:for)
        .and_return(SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :trial_expired))
    end

    it_behaves_like 'a structured entitlement denial', :trial_expired
  end
end
