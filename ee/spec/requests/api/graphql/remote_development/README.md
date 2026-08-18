# Workspaces GraphQL API resolver request integration specs

## Directory structure

The directory structure of this folder mirrors the structure of the GraphQL API schema
under the root `Query` type.

Each GraphQL field and its corresponding resolver has a corresponding spec folder containing specs which test the related resolver+finder functionality. 

Note that some entries may be reachable by other GraphQL query traversal paths, e.g., a `ClusterAgent` is reachable via `Query.project.clusterAgent...` and `Query.group.clusterAgents...`. In these cases, a single representatative example query is used in the specs, since the path used to reach a GraphQL node has no impact on the functionality of the nested fields and their resolvers.

Here are the related spec folders for the fields (in alphabetical order by resolver source file path)

- GraphQL Field: `Query.workspaces`
    - Spec folder: `ee/spec/requests/api/graphql/remote_development/workspaces`
    - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#queryworkspaces
    - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/workspaces_admin_resolver.rb`
    - Notes: Only admins may use this field.

- Field: `Query.project.clusterAgent.workspaces`
    - Spec folder: `ee/spec/requests/api/graphql/remote_development/cluster_agent/workspaces`
    - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#clusteragentworkspaces
    - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/cluster_agent/workspaces.rb`

- GraphQL Field: `Query.project.clusterAgent.workspacesAgentConfig`
  - Spec folder: `ee/spec/requests/api/graphql/remote_development/cluster_agent/workspaces_agent_config`
  - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#clusteragentworkspacesagentconfig
  - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/cluster_agent/workspaces_agent_config_resolver.rb`

- GraphQL Field: `Query.namespace.remote_development_cluster_agents`
  - Spec folder: `ee/spec/requests/api/graphql/remote_development/namespace/remote_development_cluster_agents`
  - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#namespaceremotedevelopmentclusteragents
  - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/namespace/cluster_agents_resolver.rb` 
  - Notes: This is the same resolver used by `Query.currentUser.namespace.workspaces_cluster_agents`. THIS FIELD IS DEPRECATED AND WILL BE REMOVED IN THE 18.0 RELEASE.

- GraphQL Field: `Query.namespace.namespace.workspaces_cluster_agents`
  - Spec folder: `ee/spec/requests/api/graphql/remote_development/namespace/workspaces_cluster_agents`
  - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#namespaceworkspacesclusteragents
  - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/namespace/cluster_agents_resolver.rb`
  - Notes: This is the same resolver used by `Query.currentUser.namespace.remote_development_cluster_agents`.

- GraphQL Field: `Query.workspace`
  - Spec folder: `ee/spec/requests/api/graphql/remote_development/workspace`
  - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#queryworkspace
  - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/namespace/workspaces_resolver.rb`
  - Notes: This is the same resolver used by `Query.currentUser.workspaces`

- GraphQL Field: `Query.workspace.workspaceVariables`
    - Spec folder: `ee/spec/requests/api/graphql/remote_development/workspace_variables`
    - API docs:  https://docs.gitlab.com/ee/api/graphql/reference/##workspacevariableconnection
    - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/namespace/workspaces_resolver.rb`
    - Notes: This is the same resolver used by `Query.currentUser.workspaces`

- GraphQL Field: `Query.currentUser.workspaces`
    - Spec folder: `ee/spec/requests/api/graphql/remote_development/current_user/workspaces`
    - API docs: https://docs.gitlab.com/ee/api/graphql/reference/#currentuserworkspaces
    - Resolver source file for `tests.yml` and `verify-tff-mapping`: `ee/app/graphql/resolvers/remote_development/workspaces_resolver.rb`
    - Notes: This is the same resolver used by `Query.currentUser.workspace`

The `shared.rb` file in the root contains RSpec shared contexts and examples used by all
specs in this directory.

The `shared.rb` files in the subdirectories contain shared rspec contexts and examples
specific to the query being tested.

## These are kind of complex and hard to follow. Why?

They do heavily leverage RSpec shared contexts and examples across multiple files, which requires more effort to understand how they work.

However, this allows the individual spec files to be very DRY and cohesive, yet still provide thorough coverage across multiple aspects of behavior.

Without this approach, achieving equivalent coverage across all of this same GraphQL API behavior would result in specs with significantly more verbosity and duplication.

## Adding new spec files

If you add new spec files, you should update `tests.yml` and `scripts/verify-tff-mapping` accordingly.

Add entries for relevant types and resolvers in these files.

## Why aren't all individual fields of graphql types tested in these specs?

None of these other graphql API request specs test the actual fields because that’s not necessary.

This is because between the finder specs, the GraphQL type specs, and the way GraphQL works
to automatically populate the fields into a type, the population of the individual fields in
the returned GraphQL objects is already adequately covered.

Thus, the only things these request integration specs assert are the actual logic and behavior of the resolvers
and finders, and how they integrate:
- whether they process all the arguments correctly
- whether they return the right records or not
- whether they handle errors properly
- whether they do proper authorization
- etc.
