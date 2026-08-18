# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    # Builds the shell commands that install and run Orbit local indexing
    # inside a Duo Agent Platform workload.
    #
    # Orbit local indexes the current checkout so the agent has a
    # branch-aware knowledge graph - not just the default-branch graph
    # served by the remote Orbit API.
    #
    # Gated behind the +duo_developer_orbit+ feature flag and the
    # per-user Orbit killswitch. The flow config itself is unchanged: the
    # agent picks Orbit up through the skill materialized below.
    #
    # All commands are best-effort: failures are logged as warnings and
    # never abort the workload.
    #
    # The orbit binary has runtime requirements (notably a recent GLIBC)
    # that are not satisfied by every workload base image. When the binary
    # cannot run on the host, the install step may succeed but the binary
    # will be unusable. The index and skill steps are therefore guarded by
    # an executable-bit preflight check, so we don't try to run a binary
    # that was never installed.
    #
    # The skill step materializes the orbit-local agent skill bundled inside
    # the binary (`orbit skill` prints a version-matched SKILL.md) into
    # ~/.agents/skills/, where the Duo CLI discovers it at startup and
    # surfaces it to the agent. The file must exist before `duo run`.
    # The binary is invoked directly rather than through the
    # `glab orbit local` wrapper so nothing but the skill content can reach
    # stdout. A workload note is appended so the agent queries the index
    # built above instead of re-indexing (the default DB location is not
    # writable for the agent).
    class OrbitLocalSetup
      attr_reader :current_user

      ORBIT_BIN = '"$HOME/.config/glab-cli/bin/orbit"'
      SKILL_DIR = '"$HOME/.agents/skills/orbit-local"'
      SKILL_FILE = '"$HOME/.agents/skills/orbit-local/SKILL.md"'

      # Appended to the materialized SKILL.md. The checkout is indexed by
      # index_command before the agent starts, and the default DB location
      # (~/.orbit) is not writable for the agent, so re-indexing both wastes
      # LLM calls and fails.
      WORKLOAD_NOTE = <<~MD # no single quotes: embedded in single-quoted shell
        ## Workload environment note

        This checkout was already indexed into ~/.orbit/graph.duckdb before you
        started. Query it directly (e.g. `glab orbit local --yes sql "..."`).
        Do not re-index: the default DB location is not writable in this
        environment. If you need a fresh index (e.g. after checking out a
        different commit), pass `--db /tmp/orbit.duckdb` to both `index` and
        `sql`.
      MD

      def initialize(current_user:)
        @current_user = current_user
      end

      def commands
        return [] unless enabled?

        [
          install_command,
          index_command,
          skill_command
        ]
      end

      private

      def enabled?
        Feature.enabled?(:duo_developer_orbit, current_user) &&
          ::Ai::Orbit::Settings.killswitch_on?(current_user)
      end

      def install_command
        <<~SH.squish
          glab orbit local --install --yes
          || echo "Warning: Orbit local install failed; continuing without local index" >&2
        SH
      end

      def index_command
        <<~SH.strip
          if [ -x #{ORBIT_BIN} ]; then
            glab orbit local --yes index . || echo "Warning: Orbit local indexing failed; continuing without local index" >&2
          else
            echo "Warning: Orbit local indexing skipped; continuing without local index" >&2
          fi
        SH
      end

      def skill_command
        <<~SH.strip
          if [ -x #{ORBIT_BIN} ]; then
            if mkdir -p #{SKILL_DIR} && #{ORBIT_BIN} skill > #{SKILL_FILE}; then
              printf '\\n%s' '#{WORKLOAD_NOTE}' >> #{SKILL_FILE} || echo "Warning: Orbit skill note append failed; continuing without it" >&2
            else
              rm -f #{SKILL_FILE}
              echo "Warning: Orbit skill install failed; continuing without orbit-local skill" >&2
            fi
          else
            echo "Warning: Orbit skill install skipped; continuing without orbit-local skill" >&2
          fi
        SH
      end
    end
  end
end
