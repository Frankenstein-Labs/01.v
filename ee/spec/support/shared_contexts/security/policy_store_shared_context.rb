# frozen_string_literal: true

# `Gitlab::PolicyStore.configuration` is a process-wide singleton, so the
# in-memory adapter would otherwise carry policies from one example into the
# next. The previously configured repository is restored in an `ensure` so the
# swap cannot outlive the example, and so this stays correct once a persistent
# repository is configured at boot.
RSpec.shared_context 'with an empty policy store' do
  around do |example|
    original_repository = ::Gitlab::PolicyStore.configuration.repository

    ::Gitlab::PolicyStore.configure do |config|
      config.repository = ::Gitlab::PolicyStore::Adapters::InMemoryPolicyRepository.new
    end

    example.run
  ensure
    ::Gitlab::PolicyStore.configure { |config| config.repository = original_repository }
  end

  def create_policy(**attributes)
    ::Gitlab::PolicyStore.create(attributes) # rubocop:disable Rails/SaveBang -- not ActiveRecord; the store has no create!
  end
end

RSpec.shared_context 'with the policy store experiment active' do
  before do
    stub_licensed_features(security_orchestration_policies: true)
    stub_application_setting(policy_store_experiment_enabled: true)
  end
end

# Sets up an organization with an owner (authorized to manage policies), a
# non-owner member (not authorized), and an owner of an unrelated organization
# (not authorized either; ownership does not cross organizations).
# `current_user` defaults to the owner.
RSpec.shared_context 'with policy store service authorization' do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:non_owner) { create(:user) }
  let_it_be(:foreign_organization) { create(:organization) }
  let_it_be(:foreign_org_owner) { create(:user) }

  let(:current_user) { owner }

  before_all do
    create(:organization_user, :owner, organization: organization, user: owner)
    create(:organization_user, organization: organization, user: non_owner)
    create(:organization_user, :owner, organization: foreign_organization, user: foreign_org_owner)
  end
end

RSpec.configure do |config|
  config.include_context 'with an empty policy store', :policy_store
end
