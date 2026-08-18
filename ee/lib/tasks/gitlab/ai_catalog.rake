# frozen_string_literal: true

namespace :gitlab do
  namespace :ai_catalog do
    desc 'GitLab | AI Catalog | Hydrate database with GitLab-managed agents (Claude Code, Codex)'
    task seed_external_agents: :gitlab_environment do
      Gitlab::Ai::Catalog::ThirdPartyFlows::Seeder.run!
    end
  end
end
