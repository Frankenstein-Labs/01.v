# frozen_string_literal: true

RSpec.shared_examples 'grouped evaluator concern' do
  describe '#grouped_results' do
    subject(:grouped_results) { evaluator.grouped_results }

    context 'when scanner_configurations is empty' do
      let(:params) do
        {
          scanner_configurations: [],
          **empty_config_extra_params
        }
      end

      it 'returns nil' do
        expect(grouped_results).to be_nil
      end
    end

    context 'when scanner_configurations is absent' do
      let(:params) { { **empty_config_extra_params } }

      it 'returns nil' do
        expect(grouped_results).to be_nil
      end
    end

    context 'with vulnerability_attributes containing epss_score as hash' do
      let(:params) do
        {
          scanner_configurations: [
            {
              type: 'sast',
              vulnerability_attributes: {
                epss_score: { operator: 'greater_than', value: 0.5 }
              }
            }
          ]
        }
      end

      it 'normalizes epss_score and returns results' do
        expect(grouped_results).to be_an(Array)
      end
    end

    context 'with enrichment_data_unavailable in vulnerability_attributes' do
      let(:params) do
        {
          scanner_configurations: [
            {
              type: 'sast',
              vulnerability_attributes: {
                enrichment_data_unavailable: { action: 'block' }
              }
            }
          ]
        }
      end

      it 'extracts enrichment_data_unavailable_action' do
        expect(grouped_results).to be_an(Array)
      end
    end

    context 'when scanner config has no vulnerability_attributes but rule-level params exist' do
      let(:params) do
        {
          scanner_configurations: [
            { type: 'sast', severity_levels: %w[high] }
          ],
          fix_available: true,
          false_positive: false,
          known_exploited: true,
          epss_score: { operator: 'greater_than', value: 0.5 },
          enrichment_data_unavailable_action: 'block'
        }
      end

      it 'falls back to rule-level vulnerability attributes' do
        results = grouped_results

        expect(results).to be_an(Array)
        expect(results.length).to eq(1)
      end
    end

    context 'when scanner config overrides some vulnerability_attributes while others fall back' do
      let(:params) do
        {
          scanner_configurations: [
            {
              type: 'sast',
              severity_levels: %w[high],
              vulnerability_attributes: { fix_available: false }
            }
          ],
          known_exploited: true,
          epss_score: { operator: 'greater_than', value: 0.8 }
        }
      end

      it 'uses scanner-level override for fix_available and rule-level for others' do
        results = grouped_results

        expect(results).to be_an(Array)
        expect(results.length).to eq(1)
      end
    end

    context 'with vulnerability_attributes containing epss_score as string' do
      let(:params) do
        {
          scanner_configurations: [
            {
              type: 'sast',
              vulnerability_attributes: {
                epss_score: 'greater_than:0.5'
              }
            }
          ]
        }
      end

      it 'preserves epss_score string value and returns results' do
        expect(grouped_results).to be_an(Array)
      end
    end
  end

  describe '#normalize_vulnerability_attributes' do
    let(:concern_instance) do
      concern_class = Class.new do
        include Security::ScanResultPolicies::GroupedEvaluatorConcern

        def initialize(project, params)
          @project = project
          @params = params
        end
      end

      concern_class.new(evaluator.project, params)
    end

    context 'when vulnerability attribute is explicitly false' do
      let(:params) do
        {
          scanner_configurations: [{ type: 'sast' }],
          fix_available: true,
          false_positive: true,
          known_exploited: true
        }
      end

      it 'preserves false values from attrs instead of falling back to params' do
        attributes = { fix_available: false, false_positive: false, known_exploited: false }

        result = concern_instance.send(:normalize_vulnerability_attributes, attributes)

        expect(result).to include(fix_available: false, false_positive: false, known_exploited: false)
      end
    end

    context 'when vulnerability attribute is absent' do
      let(:params) do
        {
          scanner_configurations: [{ type: 'sast' }],
          fix_available: true,
          false_positive: false
        }
      end

      it 'falls back to params when key is not present in attrs' do
        result = concern_instance.send(:normalize_vulnerability_attributes, {})

        expect(result).to include(fix_available: true, false_positive: false)
      end
    end
  end

  describe '#normalize_group_key' do
    let(:concern_instance) do
      concern_class = Class.new do
        include Security::ScanResultPolicies::GroupedEvaluatorConcern

        def initialize(project, params)
          @project = project
          @params = params
        end

        def group_key_mapping
          { vulnerabilities_allowed: :vulnerabilities_allowed }
        end
      end

      concern_class.new(evaluator.project, params)
    end

    context 'when config value is falsy (e.g. vulnerabilities_allowed: 0)' do
      let(:params) do
        {
          scanner_configurations: [{ type: 'sast' }],
          vulnerabilities_allowed: 5
        }
      end

      it 'preserves the config value instead of falling back to params' do
        config = { type: 'sast', vulnerabilities_allowed: 0 }

        result = concern_instance.send(:normalize_group_key, config)

        expect(result[:vulnerabilities_allowed]).to eq(0)
      end
    end

    context 'when config key is absent' do
      let(:params) do
        {
          scanner_configurations: [{ type: 'sast' }],
          vulnerabilities_allowed: 5
        }
      end

      it 'falls back to params' do
        config = { type: 'sast' }

        result = concern_instance.send(:normalize_group_key, config)

        expect(result[:vulnerabilities_allowed]).to eq(5)
      end
    end
  end

  describe '#group_scanners_by_attributes' do
    context 'when scanner_configurations is nil' do
      let(:params) { { **empty_config_extra_params } }

      it 'returns an empty hash' do
        expect(evaluator.send(:group_scanners_by_attributes)).to eq({})
      end
    end
  end

  describe '#group_key_mapping' do
    let(:params) { { **empty_config_extra_params } }

    it 'raises NotImplementedError when not overridden' do
      concern_class = Class.new do
        include Security::ScanResultPolicies::GroupedEvaluatorConcern

        def initialize(project, params)
          @project = project
          @params = params
        end
      end

      instance = concern_class.new(evaluator.project, params)
      expect do
        instance.send(:group_key_mapping)
      end.to raise_error(NotImplementedError, /must implement #group_key_mapping/)
    end
  end
end
