# frozen_string_literal: true

# Seeds sample rows in `namespace_secret_counts` so that the table is not
# empty in development environments. This mirrors the data that would be
# produced in production by `SecretsManagement::NamespaceSecretCounts::RefreshService`
# whenever a namespace has an active secrets manager.
Gitlab::Seeder.quiet do
  namespaces = Group.limit(20).to_a + Namespaces::ProjectNamespace.limit(20).to_a

  rows = namespaces.filter_map do |namespace|
    root = namespace.root_ancestor
    next unless root

    {
      namespace_id: namespace.id,
      root_namespace_id: root.id,
      count: rand(0..50),
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  next if rows.empty?

  SecretsManagement::NamespaceSecretCount.upsert_all(rows, unique_by: :namespace_id)

  print '.'
end
