# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Dsl::Field, feature_category: :global_search do
  # - Anonymous class to include the DSL
  # - This simulates a model declaring indexable fields
  let(:klass) do
    Class.new do
      include Search::Elastic::Dsl::Field

      class << self
        attr_accessor :fields_registry
      end

      self.fields_registry = {}
    end
  end

  describe '.field' do
    it 'registers a simple flat field in the registry' do
      klass.field(:title, type: :keyword)

      expect(klass.fields_registry).to include(
        title: hash_including(
          name: :title,
          type: :keyword,
          children: nil
        )
      )
    end

    it 'supports value, default, enrich, version, and condition options' do
      value_lambda = ->(r) { r.name.upcase }
      enrich_lambda = ->(ids) { ids.map(&:to_s) }
      default = 'fallback'

      klass.field(
        :name,
        type: :keyword,
        value: value_lambda,
        default: default,
        enrich: enrich_lambda,
        version: 5,
        if: -> { true }
      )

      node = klass.fields_registry[:name]
      expect(node).to include(
        name: :name,
        type: :keyword,
        value: value_lambda,
        default: default,
        enrich: enrich_lambda,
        version: 5,
        condition: an_instance_of(Proc)
      )
    end

    it 'defines deeply nested fields with multiple levels' do
      klass.field(:scanner, type: :object) do
        field :external_id, type: :keyword
        field :details, type: :object do
          field :vendor, type: :keyword
        end
      end

      root = klass.fields_registry[:scanner]
      expect(root[:type]).to eq(:object)
      expect(root[:children]).to include(:external_id, :details)
      expect(root[:children][:details][:children]).to include(:vendor)
    end

    it 'raises errors when DSL definition fails' do
      allow(klass).to receive(:build_node).and_raise(StandardError, 'bad field')
      expect { klass.field(:broken, type: :text) }.to raise_error(StandardError, 'bad field')
    end

    it 'handles nested valued fields correctly' do
      value_lambda = ->(_r) { 'value' }

      klass.field(:metadata, type: :object) do
        field :fingerprint, type: :keyword, value: value_lambda
      end

      nested = klass.fields_registry[:metadata][:children]
      expect(nested[:fingerprint][:value]).to eq(value_lambda)
      expect(nested[:fingerprint][:type]).to eq(:keyword)
    end

    it 'includes nested fields with defaults and conditions' do
      klass.field(:details, type: :object) do
        field :vendor, type: :keyword, default: 'gitlab'
        field :enabled, type: :boolean, if: -> { false }
      end

      nested = klass.fields_registry[:details][:children]
      expect(nested[:vendor][:default]).to eq('gitlab')
      expect(nested[:enabled][:condition]).to be_a(Proc)
    end

    it 'registers versioned nested fields' do
      klass.field(:metadata, type: :object) do
        field :versioned_key, type: :keyword, version: 10
      end

      nested = klass.fields_registry[:metadata][:children]
      expect(nested[:versioned_key][:version]).to eq(10)
    end

    it 'allows combining nested value, default, and enrich' do
      value_lambda = ->(r) { "valued-#{r.id}" }
      enrich_lambda = ->(ids) { ids.map(&:to_s) }

      klass.field(:context, type: :object) do
        field :cid, type: :keyword, value: value_lambda, default: 'no-id', enrich: enrich_lambda
      end

      nested = klass.fields_registry[:context][:children]
      expect(nested[:cid]).to include(
        type: :keyword,
        value: value_lambda,
        default: 'no-id',
        enrich: enrich_lambda
      )
    end

    it 'raises errors when nested field definitions fail' do
      expect do
        klass.field(:container, type: :object) do
          field :valid_field, type: :keyword
          field :broken_field, type: :keyword do
            raise 'invalid nested field'
          end
        end
      end.to raise_error(RuntimeError, 'invalid nested field')
    end

    it 'logs and raises if top-level nested block fails' do
      expect do
        klass.field(:failing, type: :object) do
          raise 'top-level nested failure'
        end
      end.to raise_error(RuntimeError, 'top-level nested failure')
    end
  end
end
