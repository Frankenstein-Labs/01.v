# frozen_string_literal: true

RSpec.shared_examples 'with model allowlist' do
  it 'defaults to disabled with empty identifiers', :aggregate_failures do
    feature_setting.save!

    expect(feature_setting.model_allowlist_enabled).to be(false)
    expect(feature_setting.model_allowlist_gitlab_model_refs).to eq([])
  end

  it 'accepts a non-empty allowlist' do
    feature_setting.model_allowlist_enabled = true
    feature_setting.model_allowlist_gitlab_model_refs = %w[claude_sonnet_4_20250514]

    expect(feature_setting).to be_valid
  end

  it 'rejects blank identifiers', :aggregate_failures do
    feature_setting.model_allowlist_gitlab_model_refs = ['claude_sonnet_4_20250514', '']

    expect(feature_setting).not_to be_valid
    expect(feature_setting.errors[:model_allowlist_gitlab_model_refs])
      .to include('must contain non-blank strings')
  end

  it 'rejects non-boolean enabled values', :aggregate_failures do
    feature_setting.model_allowlist_enabled = nil

    expect(feature_setting).not_to be_valid
    expect(feature_setting.errors[:model_allowlist_enabled]).to be_present
  end

  it 'rejects allowlists exceeding the maximum size', :aggregate_failures do
    max = Ai::ModelSelection::ModelAllowlist::MAX_MODEL_REFS
    feature_setting.model_allowlist_gitlab_model_refs = Array.new(max + 1) { |i| "model_#{i}" }

    expect(feature_setting).not_to be_valid
    expect(feature_setting.errors[:model_allowlist_gitlab_model_refs]).to be_present
  end

  it 'accepts allowlists at the maximum size' do
    max = Ai::ModelSelection::ModelAllowlist::MAX_MODEL_REFS
    feature_setting.model_allowlist_gitlab_model_refs = Array.new(max) { |i| "model_#{i}" }

    expect(feature_setting).to be_valid
  end

  describe '#model_allowlist_supported?' do
    context 'when feature is Agentic Chat' do
      it 'returns true' do
        feature_setting.feature = ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name

        expect(feature_setting.model_allowlist_supported?).to be(true)
      end
    end

    context 'when feature is not Agentic Chat' do
      it 'returns false' do
        feature_setting.feature = :code_completions

        expect(feature_setting.model_allowlist_supported?).to be(false)
      end
    end
  end

  describe '#currently_chosen_model_ref' do
    let(:model_definition_parser) do
      ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(feature_setting.model_definitions)
    end

    context 'when offered_model_ref is set' do
      it 'returns offered_model_ref' do
        feature_setting.offered_model_ref = 'some_offered_ref'

        expect(feature_setting.currently_chosen_model_ref(model_definition_parser)).to eq('some_offered_ref')
      end
    end

    context 'when offered_model_ref is blank' do
      before do
        feature_setting.offered_model_ref = nil
      end

      it 'falls back to the GitLab default model ref from definitions' do
        expected_default = model_definition_parser.default_model_ref_for_feature(feature_setting.feature)

        expect(expected_default).to be_present
        expect(feature_setting.currently_chosen_model_ref(model_definition_parser)).to eq(expected_default)
      end

      context 'and the parser cannot resolve a default for the feature' do
        let(:model_definition_parser) do
          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(nil)
        end

        it 'returns nil' do
          expect(feature_setting.currently_chosen_model_ref(model_definition_parser)).to be_nil
        end
      end

      context 'and the parser is nil' do
        it 'returns nil' do
          expect(feature_setting.currently_chosen_model_ref(nil)).to be_nil
        end
      end
    end
  end

  describe '#effective_allowed_model_refs' do
    let(:model_definition_parser) do
      ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(feature_setting.model_definitions)
    end

    let(:chosen_ref) { feature_setting.currently_chosen_model_ref(model_definition_parser) }

    context 'when the allowlist is disabled' do
      it 'returns an empty array' do
        feature_setting.model_allowlist_enabled = false
        feature_setting.model_allowlist_gitlab_model_refs = %w[stored_ref_a stored_ref_b]

        expect(feature_setting.effective_allowed_model_refs(model_definition_parser)).to eq([])
      end
    end

    context 'when the allowlist is enabled' do
      before do
        feature_setting.model_allowlist_enabled = true
      end

      it 'unions stored refs with the currently chosen ref and deduplicates' do
        feature_setting.model_allowlist_gitlab_model_refs = %w[stored_ref_a stored_ref_b]

        result = feature_setting.effective_allowed_model_refs(model_definition_parser)

        expect(result).to contain_exactly('stored_ref_a', 'stored_ref_b', chosen_ref)
      end

      it 'tolerates the currently chosen ref already being in the stored array' do
        feature_setting.model_allowlist_gitlab_model_refs = ['stored_ref_a', chosen_ref]

        result = feature_setting.effective_allowed_model_refs(model_definition_parser)

        expect(result).to contain_exactly('stored_ref_a', chosen_ref)
      end

      it 'strips blank entries' do
        feature_setting.model_allowlist_gitlab_model_refs = ['stored_ref_a', '']

        result = feature_setting.effective_allowed_model_refs(model_definition_parser)

        expect(result).to contain_exactly('stored_ref_a', chosen_ref)
      end

      context 'and there is no currently chosen ref' do
        let(:model_definition_parser) do
          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(nil)
        end

        it 'returns only the stored refs' do
          feature_setting.offered_model_ref = nil
          feature_setting.model_allowlist_gitlab_model_refs = %w[stored_ref_a stored_ref_b]

          result = feature_setting.effective_allowed_model_refs(model_definition_parser)

          expect(result).to contain_exactly('stored_ref_a', 'stored_ref_b')
        end
      end
    end
  end

  describe '#normalize_allowlist_model_refs' do
    let(:model_definition_parser) do
      ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(feature_setting.model_definitions)
    end

    let(:chosen_ref) { feature_setting.currently_chosen_model_ref(model_definition_parser) }

    let(:selectable_refs) do
      model_definition_parser.selectable_model_refs_for_feature(feature_setting.feature)
    end

    # Pick two selectable refs that are not the currently chosen one. The
    # factory model definitions always provide at least two non-chosen
    # selectable models for the default feature of each setting class.
    let(:non_chosen_refs) { (selectable_refs - [chosen_ref]).first(2) }
    let(:ref_a) { non_chosen_refs.first }
    let(:ref_b) { non_chosen_refs.second }

    context 'when enabled is false' do
      it 'returns an empty array regardless of submitted refs' do
        result = feature_setting.normalize_allowlist_model_refs(
          [ref_a, ref_b],
          enabled: false,
          model_definition_parser: model_definition_parser
        )

        expect(result).to eq([])
      end
    end

    context 'when enabled is true' do
      it 'deduplicates submitted refs and strips blanks' do
        result = feature_setting.normalize_allowlist_model_refs(
          [ref_a, ref_a, '', nil, ref_b],
          enabled: true,
          model_definition_parser: model_definition_parser
        )

        expect(result).to contain_exactly(ref_a, ref_b)
      end

      it 'strips the currently chosen ref from submitted refs' do
        result = feature_setting.normalize_allowlist_model_refs(
          [ref_a, chosen_ref, ref_b],
          enabled: true,
          model_definition_parser: model_definition_parser
        )

        expect(result).to contain_exactly(ref_a, ref_b)
      end

      it 'drops refs that are not in the currently selectable model definitions' do
        result = feature_setting.normalize_allowlist_model_refs(
          [ref_a, 'deprecated_or_unknown_ref', ref_b],
          enabled: true,
          model_definition_parser: model_definition_parser
        )

        expect(result).to contain_exactly(ref_a, ref_b)
      end

      it 'returns an empty array when no submitted ref is currently selectable' do
        result = feature_setting.normalize_allowlist_model_refs(
          %w[deprecated_ref_one deprecated_ref_two],
          enabled: true,
          model_definition_parser: model_definition_parser
        )

        expect(result).to eq([])
      end

      it 'accepts nil submitted refs as empty input' do
        result = feature_setting.normalize_allowlist_model_refs(
          nil,
          enabled: true,
          model_definition_parser: model_definition_parser
        )

        expect(result).to eq([])
      end

      context 'and the parser is nil' do
        it 'skips the selectable-refs intersection and returns the deduped submitted refs' do
          feature_setting.offered_model_ref = nil

          result = feature_setting.normalize_allowlist_model_refs(
            ['ref_a', 'ref_a', '', 'ref_b'],
            enabled: true,
            model_definition_parser: nil
          )

          expect(result).to contain_exactly('ref_a', 'ref_b')
        end
      end

      context 'and the parser has no definitions for the feature' do
        let(:model_definition_parser) do
          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(nil)
        end

        it 'intersects against an empty selectable list and returns []' do
          feature_setting.offered_model_ref = nil

          result = feature_setting.normalize_allowlist_model_refs(
            %w[ref_a ref_b],
            enabled: true,
            model_definition_parser: model_definition_parser
          )

          expect(result).to eq([])
        end
      end
    end
  end
end
