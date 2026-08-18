# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Upstreams::FiltrationService, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group:) }

  let(:service) { described_class.new(upstreams:, relative_path:) }

  describe '#execute' do
    subject(:execute) { service.execute }

    describe 'input validation' do
      let(:test_upstreams) { [build(:virtual_registries_packages_maven_upstream)] }
      let(:test_relative_path) { 'com/example/my-app/1.0.0/my-app-1.0.0.jar' }

      where(:upstreams, :relative_path, :expected_error) do
        []                   | ref(:test_relative_path) | described_class::NO_UPSTREAMS_ERROR
        ref(:test_upstreams) | ''                       | described_class::NO_RELATIVE_PATH_ERROR
        ref(:test_upstreams) | '/'                      | described_class::NO_COORDINATES_ERROR
      end

      with_them do
        it { is_expected.to be_error.and have_attributes(message: expected_error) }
      end
    end

    describe 'rule evaluation' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

      let(:upstreams) { [upstream] }
      let(:relative_path) { 'com/example/my-app/1.0.0/my-app-1.0.0.jar' }

      context 'with no rules' do
        it 'returns all upstreams as allowed and none as denied' do
          is_expected.to be_success.and have_attributes(
            payload: a_hash_including(allowed_upstreams: [upstream], denied_upstreams: [])
          )
        end
      end

      describe 'single rule scenarios' do
        where(:description, :rule_type, :pattern, :should_include) do
          'matching allow rule'     | :allow | 'com.example' | true
          'non-matching allow rule' | :allow | 'org.other'   | false
          'matching deny rule'      | :deny  | 'com.example' | false
          'non-matching deny rule'  | :deny  | 'org.other'   | true
        end

        with_them do
          before do
            create(:virtual_registries_packages_maven_upstream_rule,
              :group_id,
              :wildcard,
              remote_upstream: upstream,
              rule_type: rule_type,
              pattern: pattern
            )
          end

          it "handles #{params[:description]}" do
            is_expected.to be_success

            allowed_ids = execute[:allowed_upstreams].map(&:id)
            expect(allowed_ids.include?(upstream.id)).to eq(should_include)
          end
        end
      end

      describe 'multiple rules scenarios' do
        where(:description, :rules, :should_include) do
          'multiple allow rules, all match'   | [[:allow, 'com.*'], [:allow, 'com.example']]      | true
          'multiple allow rules, one matches' | [[:allow, 'org.other'], [:allow, 'com.example']]  | true
          'multiple allow rules, none match'  | [[:allow, 'org.other'], [:allow, 'net.foo']]      | false
          'multiple deny rules, all match'    | [[:deny, 'com.*'], [:deny, 'com.example']]        | false
          'multiple deny rules, one matches'  | [[:deny, 'org.other'], [:deny, 'com.example']]    | false
          'multiple deny rules, none match'   | [[:deny, 'org.other'], [:deny, 'net.foo']]        | true
          'deny takes precedence over allow'  | [[:allow, 'com.example'], [:deny, 'com.example']] | false
        end
        with_them do
          before do
            rules.each do |rule_type, pattern|
              create(:virtual_registries_packages_maven_upstream_rule,
                :group_id,
                :wildcard,
                rule_type,
                remote_upstream: upstream,
                pattern: pattern)
            end
          end

          it "handles #{params[:description]}" do
            is_expected.to be_success

            allowed_ids = execute[:allowed_upstreams].map(&:id)
            expect(allowed_ids.include?(upstream.id)).to eq(should_include)
          end
        end
      end

      describe 'rules across coordinates' do
        where(:description, :group_rule, :artifact_rule, :should_include) do
          'all coordinates match'     | [:allow, 'com.example'] | [:allow, 'my-app']    | true
          'one coordinate fails'      | [:allow, 'com.example'] | [:allow, 'other-app'] | false
          'deny on any coordinate'    | [:allow, 'com.example'] | [:deny, 'my-app']     | false
        end
        with_them do
          before do
            create(:virtual_registries_packages_maven_upstream_rule,
              :group_id,
              :wildcard,
              remote_upstream: upstream,
              rule_type: group_rule[0],
              pattern: group_rule[1])

            create(:virtual_registries_packages_maven_upstream_rule,
              :artifact_id,
              :wildcard,
              remote_upstream: upstream,
              rule_type: artifact_rule[0],
              pattern: artifact_rule[1])
          end

          it "handles #{params[:description]}" do
            is_expected.to be_success

            allowed_ids = execute[:allowed_upstreams].map(&:id)
            expect(allowed_ids.include?(upstream.id)).to eq(should_include)
          end
        end
      end
    end

    describe 'pattern matching' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

      let(:upstreams) { [upstream] }

      describe 'wildcard patterns' do
        let(:relative_path) { 'com/example/my-app/1.0.0/my-app-1.0.0.jar' }

        where(:description, :target_coordinate, :rule_type, :pattern, :should_match) do
          'exact match'             | :group_id    | :allow | 'com.example' | true
          'leading wildcard'        | :group_id    | :allow | '*.example'   | true
          'trailing wildcard'       | :group_id    | :allow | 'com.*'       | true
          'multiple wildcard'       | :version     | :allow | '1.*.*'       | true
          'case insensitive'        | :group_id    | :allow | 'COM.EXAMPLE' | true
          'non-matching group'      | :group_id    | :allow | 'org.apache'  | false
          'non-matching artifact'   | :artifact_id | :allow | 'other-app'   | false
          'non-matching version'    | :version     | :allow | '2.*'         | false

          'exact match'             | :group_id    | :deny  | 'com.example' | false
          'leading wildcard'        | :group_id    | :deny  | '*.example'   | false
          'trailing wildcard'       | :group_id    | :deny  | 'com.*'       | false
          'multiple wildcard'       | :version     | :deny  | '1.*.*'       | false
          'case insensitive'        | :group_id    | :deny  | 'COM.EXAMPLE' | false
          'non-matching group'      | :group_id    | :deny  | 'org.apache'  | true
          'non-matching artifact'   | :artifact_id | :deny  | 'other-app'   | true
          'non-matching version'    | :version     | :deny  | '2.*'         | true
        end

        with_them do
          before do
            create(:virtual_registries_packages_maven_upstream_rule,
              :wildcard,
              rule_type,
              target_coordinate,
              remote_upstream: upstream,
              pattern: pattern)
          end

          it "handles #{params[:description]} with #{params[:rule_type]} rule" do
            is_expected.to be_success

            allowed_ids = execute[:allowed_upstreams].map(&:id)
            expect(allowed_ids.include?(upstream.id)).to eq(should_match)
          end
        end
      end

      describe 'regex patterns' do
        let(:relative_path) { 'com/example/my-app/1.0.0/my-app-1.0.0.jar' }

        where(:description, :target_coordinate, :rule_type, :pattern, :should_match) do
          'exact match'             | :group_id | :allow | '^com\.example$'           | true
          'partial match'           | :group_id | :allow | 'example'                  | true
          'character class'         | :version  | :allow | '^[0-9]+\.[0-9]+\.[0-9]+$' | true
          'alternation'             | :group_id | :allow | '^(com|org)\.example$'     | true
          'case insensitive'        | :group_id | :allow | '^COM\.EXAMPLE$'           | true
          'non-matching'            | :group_id | :allow | '^org\.apache'             | false

          'exact match'             | :group_id | :deny  | '^com\.example$'           | false
          'partial match'           | :group_id | :deny  | 'example'                  | false
          'character class'         | :version  | :deny  | '^[0-9]+\.[0-9]+\.[0-9]+$' | false
          'alternation'             | :group_id | :deny  | '^(com|org)\.example$'     | false
          'case insensitive'        | :group_id | :deny  | '^COM\.EXAMPLE$'           | false
          'non-matching'            | :group_id | :deny  | '^org\.apache'             | true
        end

        with_them do
          before do
            create(:virtual_registries_packages_maven_upstream_rule,
              :regex,
              rule_type,
              target_coordinate,
              remote_upstream: upstream,
              pattern: pattern)
          end

          it "handles #{params[:description]}" do
            is_expected.to be_success

            allowed_ids = execute[:allowed_upstreams].map(&:id)
            expect(allowed_ids.include?(upstream.id)).to eq(should_match)
          end
        end
      end
    end

    describe 'multiple upstreams filtering' do
      let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
      let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
      let_it_be(:upstream3) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

      let(:upstreams) { [upstream1, upstream2, upstream3] }
      let(:relative_path) { 'com/example/my-app/1.0.0/my-app-1.0.0.jar' }

      # Rules format: { upstream_index => [[target_coordinate, pattern_type, rule_type, pattern], ...] }
      # rubocop:disable Layout/LineLength -- better readability
      where(:description, :rules_config, :expected_upstream_indices) do
        'no rules on any upstream'              | {}                                                                                                                                                                                          | [1, 2, 3]
        'all upstreams denied'                  | { 1 => [[:group_id, :wildcard, :deny, '*']], 2 => [[:group_id, :wildcard, :deny, '*']], 3 => [[:group_id, :wildcard, :deny, '*']] }                                                         | []
        'all upstreams allowed'                 | { 1 => [[:group_id, :wildcard, :allow, 'com.*']], 2 => [[:group_id, :wildcard, :allow, 'com.*']], 3 => [[:group_id, :wildcard, :allow, 'com.*']] }                                          | [1, 2, 3]
        'one denied, others no rules'           | { 1 => [[:group_id, :wildcard, :deny, 'com.example']] }                                                                                                                                     | [2, 3]
        'one allowed, others no rules'          | { 1 => [[:group_id, :wildcard, :allow, 'com.example']] }                                                                                                                                    | [1, 2, 3]
        'one non-matching allow, others none'   | { 1 => [[:group_id, :wildcard, :allow, 'org.other']] }                                                                                                                                      | [2, 3]
        'mixed: allow, deny, no rules'          | { 1 => [[:group_id, :wildcard, :allow, 'com.*']], 2 => [[:group_id, :wildcard, :deny, 'com.example']] }                                                                                     | [1, 3]
        'mixed pattern types across upstreams'  | { 1 => [[:group_id, :wildcard, :allow, 'com.*']], 2 => [[:group_id, :regex, :allow, '^com\.example$']], 3 => [[:group_id, :regex, :deny, 'example']] }                                      | [1, 2]
        'multiple rules per upstream'           | { 1 => [[:group_id, :wildcard, :allow, 'com.*'], [:artifact_id, :wildcard, :allow, 'my-app']], 2 => [[:group_id, :wildcard, :allow, 'com.*'], [:artifact_id, :wildcard, :deny, 'my-app']] } | [1, 3]
        'deny overrides allow same upstream'    | { 1 => [[:group_id, :wildcard, :allow, 'com.*'], [:group_id, :wildcard, :deny, 'com.example']] }                                                                                            | [2, 3]
      end
      # rubocop:enable Layout/LineLength

      with_them do
        let(:upstream_map) { { 1 => upstream1, 2 => upstream2, 3 => upstream3 } }

        before do
          rules_config.each do |upstream_index, rules|
            upstream = upstream_map[upstream_index]
            rules.each do |target_coordinate, pattern_type, rule_type, pattern|
              create(:virtual_registries_packages_maven_upstream_rule,
                target_coordinate,
                pattern_type,
                rule_type,
                remote_upstream: upstream,
                pattern: pattern)
            end
          end
        end

        it "handles #{params[:description]}" do
          expected_allowed_ids = expected_upstream_indices.map { |i| upstream_map[i].id }
          expected_denied_ids = upstream_map.values.map(&:id) - expected_allowed_ids

          is_expected.to be_success

          expect(execute[:allowed_upstreams].map(&:id)).to match_array(expected_allowed_ids)
          expect(execute[:denied_upstreams].map(&:id)).to match_array(expected_denied_ids)
        end
      end
    end

    describe 'different relative paths' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

      let(:upstreams) { [upstream] }

      # Rule format: [target_coordinate, pattern_type, rule_type, pattern]
      # rubocop:disable Layout/LineLength -- better readability
      where(:description, :relative_path, :rule, :should_include) do
        # Snapshot artifact paths
        'snapshot artifact, matching version'       | 'com/example/my-app/1.0.0-SNAPSHOT/my-app-1.0.0-SNAPSHOT.jar' | [:version, :wildcard, :allow, '*-SNAPSHOT']   | true
        'snapshot artifact, deny snapshot version'  | 'com/example/my-app/1.0.0-SNAPSHOT/my-app-1.0.0-SNAPSHOT.jar' | [:version, :wildcard, :deny, '*-SNAPSHOT']    | false
        'snapshot artifact, matching regex version' | 'com/example/my-app/1.0.0-SNAPSHOT/my-app-1.0.0-SNAPSHOT.jar' | [:version, :regex, :deny, '-SNAPSHOT$']       | false
        'snapshot artifact, matching group'         | 'com/example/my-app/1.0.0-SNAPSHOT/my-app-1.0.0-SNAPSHOT.jar' | [:group_id, :wildcard, :allow, 'com.example'] | true

        # Artifact-level metadata (no version directory)
        'artifact metadata, matching group'       | 'com/example/my-app/maven-metadata.xml' | [:group_id, :wildcard, :allow, 'com.example'] | true
        'artifact metadata, deny group'           | 'com/example/my-app/maven-metadata.xml' | [:group_id, :wildcard, :deny, 'com.example']  | false
        'artifact metadata, matching artifact'    | 'com/example/my-app/maven-metadata.xml' | [:artifact_id, :wildcard, :allow, 'my-app']   | true
        'artifact metadata, version rule ignored' | 'com/example/my-app/maven-metadata.xml' | [:version, :wildcard, :deny, '*']             | true
      end
      # rubocop:enable Layout/LineLength

      with_them do
        before do
          create(:virtual_registries_packages_maven_upstream_rule,
            rule[0], rule[1], rule[2],
            remote_upstream: upstream,
            pattern: rule[3])
        end

        it "handles #{params[:description]}" do
          is_expected.to be_success

          allowed_ids = execute[:allowed_upstreams].map(&:id)
          expect(allowed_ids.include?(upstream.id)).to eq(should_include)
        end
      end
    end
  end
end
