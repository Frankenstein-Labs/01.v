# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::PolicyEvaluator, feature_category: :dependency_firewall do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:policy_config) { create(:security_orchestration_policy_configuration, project: project) }

  let(:name) { 'lodash' }
  let(:purl_type) { 'npm' }
  let(:version) { '4.17.21' }
  let(:licenses) { ['MIT'] }
  let(:malicious_packages) { [] }

  let(:denied_mit_rule) { { type: 'license', denied: [{ name: 'MIT' }] } }
  let(:allowed_mit_rule) { { type: 'license', allowed: [{ name: 'MIT' }] } }
  let(:denied_malicious_rule) { { type: 'malicious', denied: [{ is_malicious: true }] } }

  subject(:result) do
    described_class.new(project, user).evaluate(name,
      purl_type: purl_type, version: version, licenses: licenses, malicious_packages: malicious_packages)
  end

  before do
    stub_feature_flags(dependency_firewall_phase1: true)
  end

  # Creates a valid Security::Policy record for the dependency_firewall_policy type and links it
  # to the project via security_policy_project_links so project.security_policies finds it.
  # policy_index must be unique per (policy_config, type) within a single test example.
  def create_firewall_policy(
    name:, rules:, bypass_settings: { users: [], access_tokens: [] },
    enforcement_type: 'enforced', policy_index: 0)
    policy = create(:security_policy, :dependency_firewall_policy,
      security_orchestration_policy_configuration: policy_config,
      name: name,
      policy_index: policy_index,
      linked_projects: [project],
      content: {
        name: name,
        enabled: true,
        enforcement_type: enforcement_type,
        rules: rules,
        bypass_settings: bypass_settings
      })

    Array.wrap(policy.content&.deep_symbolize_keys&.dig(:rules)).each_with_index do |rule_hash, index|
      create(:dependency_firewall_policy_rule,
        security_policy: policy,
        rule_index: index,
        type: Security::DependencyFirewallPolicyRule.types[rule_hash[:type]],
        content: rule_hash.except(:type))
    end

    policy
  end

  describe '#evaluate' do
    context 'when policies are empty' do
      it { is_expected.to eq([]) }
    end

    context 'when config contains non-firewall policies' do
      before do
        # Use save without validation to create a record of a different type without meeting that
        # type's content schema - testing that the evaluator's type filter works correctly.
        build(:security_policy,
          security_orchestration_policy_configuration: policy_config,
          type: Security::Policy.types[:scan_execution_policy],
          content: {},
          policy_index: 0
        ).tap do |p|
          p.save!(validate: false)
          create(:security_policy_project_link, project: project, security_policy: p)
        end

        create_firewall_policy(name: 'fw-policy', rules: [denied_mit_rule], policy_index: 1)
      end

      it 'evaluates only firewall policies' do
        is_expected.to contain_exactly(include(action: :denied, policy_name: 'fw-policy'))
      end
    end

    context 'when license matches a denied rule' do
      before do
        create_firewall_policy(name: 'test-policy', rules: [denied_mit_rule])
      end

      it 'returns denied result' do
        is_expected.to contain_exactly(include(action: :denied, reason: :evaluation, policy_name: 'test-policy'))
      end
    end

    context 'when license matches an allowed rule' do
      before do
        create_firewall_policy(name: 'test-policy', rules: [allowed_mit_rule])
      end

      it 'returns allowed result' do
        is_expected.to contain_exactly(include(action: :allowed, reason: :evaluation, policy_name: 'test-policy'))
      end
    end

    context 'when license does not match the denial rule' do
      let(:licenses) { ['GPL-3.0'] }

      before do
        create_firewall_policy(name: 'test-policy', rules: [denied_mit_rule])
      end

      it 'returns allowed result' do
        is_expected.to contain_exactly(include(action: :allowed, reason: :evaluation, policy_name: 'test-policy'))
      end
    end

    context 'when purl is in the rule exceptions list' do
      before do
        create_firewall_policy(name: 'test-policy',
          rules: [
            {
              type: 'license',
              denied: [{ name: 'MIT' }],
              exceptions: [{ purl: 'pkg:npm/lodash@4.17.21' }]
            }
          ])
      end

      it 'returns exception result for the excepted purl' do
        is_expected.to contain_exactly(include(action: :allowed, reason: :exception, policy_name: 'test-policy'))
      end
    end

    context 'when user is in the policy bypass list' do
      before do
        create_firewall_policy(name: 'test-policy', rules: [denied_mit_rule],
          bypass_settings: { users: [{ id: user.id }], access_tokens: [] })
      end

      it 'returns user bypassed result' do
        is_expected.to contain_exactly(include(action: :allowed, reason: :user_bypassed, policy_name: 'test-policy'))
      end
    end

    context 'when user has a bypassing access token' do
      before do
        create_firewall_policy(name: 'test-policy', rules: [denied_mit_rule],
          bypass_settings: {
            users: [],
            access_tokens: [{ id: create(:personal_access_token, user: user).id }]
          })
      end

      it 'returns token bypassed result' do
        is_expected.to contain_exactly(include(action: :allowed, reason: :token_bypassed, policy_name: 'test-policy'))
      end
    end

    context 'with multiple policies' do
      before do
        create_firewall_policy(name: 'allow-policy', rules: [allowed_mit_rule], policy_index: 0)
        create_firewall_policy(name: 'deny-policy', rules: [denied_mit_rule], policy_index: 1)
      end

      it 'returns results from all policies' do
        is_expected.to contain_exactly(
          include(action: :allowed, reason: :evaluation, policy_name: 'allow-policy'),
          include(action: :denied, reason: :evaluation, policy_name: 'deny-policy')
        )
      end
    end

    context 'with multiple rules where one denies and one allows' do
      before do
        create_firewall_policy(name: 'mixed-policy', rules: [allowed_mit_rule, denied_mit_rule])
      end

      it 'returns denied result because any denying rule takes precedence' do
        is_expected.to contain_exactly(include(action: :denied, reason: :evaluation, policy_name: 'mixed-policy'))
      end
    end

    context 'with multiple rules that all deny' do
      before do
        create_firewall_policy(name: 'test-policy', rules: [
          denied_mit_rule, { type: 'license', denied: [{ name: 'MIT' }] }
        ])
      end

      it 'returns denied result' do
        is_expected.to contain_exactly(include(action: :denied, reason: :evaluation, policy_name: 'test-policy'))
      end
    end

    context 'when enforcement_type is enforced' do
      before do
        create_firewall_policy(name: 'enforced-policy', rules: [denied_mit_rule], enforcement_type: 'enforced')
      end

      it 'returns denied result when rule denies' do
        is_expected.to contain_exactly(include(action: :denied, reason: :evaluation, policy_name: 'enforced-policy'))
      end
    end

    context 'when enforcement_type is warn' do
      context 'when rule denies' do
        before do
          create_firewall_policy(name: 'warn-policy', rules: [denied_mit_rule], enforcement_type: 'warn')
        end

        it 'returns warned result' do
          is_expected.to contain_exactly(include(action: :warned, reason: :evaluation, policy_name: 'warn-policy'))
        end
      end

      context 'when rule allows' do
        before do
          create_firewall_policy(name: 'warn-policy', rules: [allowed_mit_rule], enforcement_type: 'warn')
        end

        it 'returns allowed result' do
          is_expected.to contain_exactly(include(action: :allowed, reason: :evaluation, policy_name: 'warn-policy'))
        end
      end
    end

    context 'with multiple policies having different enforcement types' do
      before do
        create_firewall_policy(name: 'enforced-policy', rules: [denied_mit_rule],
          enforcement_type: 'enforced', policy_index: 0)
        create_firewall_policy(name: 'warn-policy', rules: [denied_mit_rule],
          enforcement_type: 'warn', policy_index: 1)
      end

      it 'returns correct action for each policy' do
        is_expected.to contain_exactly(
          include(action: :denied, policy_name: 'enforced-policy'),
          include(action: :warned, policy_name: 'warn-policy')
        )
      end
    end

    context 'with a malicious rule' do
      # The denied/allowed distinction here depends solely on malicious_packages being forwarded
      # into the rule metadata, so these also cover that forwarding.
      context 'when the package is flagged as malicious' do
        let(:malicious_packages) { [{ advisory: { id: 'MAL-0001' } }] }

        before do
          create_firewall_policy(name: 'malicious-policy', rules: [denied_malicious_rule])
        end

        it 'returns denied result' do
          is_expected.to contain_exactly(include(action: :denied, reason: :evaluation, policy_name: 'malicious-policy'))
        end
      end

      context 'when the package is flagged as malicious under warn enforcement' do
        let(:malicious_packages) { [{ advisory: { id: 'MAL-0001' } }] }

        before do
          create_firewall_policy(name: 'malicious-warn-policy', rules: [denied_malicious_rule],
            enforcement_type: 'warn')
        end

        it 'returns warned result' do
          is_expected.to contain_exactly(
            include(action: :warned, reason: :evaluation, policy_name: 'malicious-warn-policy')
          )
        end
      end

      context 'when no malicious data flags the package' do
        let(:malicious_packages) { [] }

        before do
          create_firewall_policy(name: 'malicious-policy', rules: [denied_malicious_rule])
        end

        it 'returns allowed result' do
          is_expected.to contain_exactly(
            include(action: :allowed, reason: :evaluation, policy_name: 'malicious-policy')
          )
        end
      end
    end

    context 'with the matched_rule detail' do
      context 'when a rule denies' do
        before do
          create_firewall_policy(name: 'deny-policy', rules: [denied_mit_rule])
        end

        it 'includes the deciding rule in the denied result' do
          is_expected.to contain_exactly(
            include(action: :denied, matched_rule: have_attributes(type: 'license', denied_names: ['MIT']))
          )
        end
      end

      context 'when a rule denies under warn enforcement' do
        before do
          create_firewall_policy(name: 'warn-policy', rules: [denied_mit_rule], enforcement_type: 'warn')
        end

        it 'includes the deciding rule in the warned result' do
          is_expected.to contain_exactly(
            include(action: :warned, matched_rule: have_attributes(type: 'license', denied_names: ['MIT']))
          )
        end
      end

      context 'when a rule allows' do
        before do
          create_firewall_policy(name: 'allow-policy', rules: [allowed_mit_rule])
        end

        it 'does not include a matched_rule' do
          expect(result.first).not_to have_key(:matched_rule)
        end
      end
    end

    it 'does not produce an N+1 when iterating policies' do
      evaluator = described_class.new(project, user)

      create_list(:security_policy, 3, :dependency_firewall_policy)

      control = ActiveRecord::QueryRecorder.new { evaluator.send(:policies).each(&:rules) }

      create_list(:security_policy, 3, :dependency_firewall_policy)

      expect { evaluator.send(:policies).each(&:rules) }.not_to exceed_query_limit(control)
    end
  end
end
