# frozen_string_literal: true

# The including context must define:
# - post_mutation: the subject that posts the GraphQL mutation
# - inactive_namespace: the group or project the mutation operates on (it gets archived here)
# and must run inside a context where current_user is already authorized for the mutation.
RSpec.shared_examples 'a secrets manager mutation blocked on an inactive namespace' do
  before do
    if inactive_namespace.is_a?(Group)
      inactive_namespace.namespace_settings.update!(archived: true)
    else
      inactive_namespace.update!(archived: true)
    end
  end

  it 'blocks the write and returns the inactive-namespace error' do
    post_mutation

    expected_message =
      if inactive_namespace.is_a?(Group)
        SecretsManagement::RequiresActiveNamespace::GROUP_INACTIVE_ERROR
      else
        SecretsManagement::RequiresActiveNamespace::PROJECT_INACTIVE_ERROR
      end

    expect_graphql_errors_to_include(expected_message)
  end
end
