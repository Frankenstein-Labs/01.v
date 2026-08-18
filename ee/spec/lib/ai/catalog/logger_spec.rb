# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Logger, feature_category: :workflow_catalog do
  subject(:logger) { described_class.new('/dev/null') }

  it_behaves_like 'a json logger', { 'feature_category' => 'workflow_catalog' }

  describe '#context' do
    let_it_be(:klass) { 'MyClass' }
    let_it_be(:item) { build_stubbed(:ai_catalog_item) }
    let_it_be(:version) { build_stubbed(:ai_catalog_item_version, item: item) }
    let_it_be(:consumer) { build_stubbed(:ai_catalog_item_consumer, item: item) }

    it 'sets multiple values at once' do
      logger.context(klass: klass, item: item, version: version, consumer: consumer)

      expect(logger.send(:klass)).to eq(klass)
      expect(logger.send(:item)).to eq(item)
      expect(logger.send(:version)).to eq(version)
      expect(logger.send(:consumer)).to eq(consumer)
    end

    it 'does not override values not provided in subsequent calls, but allows setting nils' do
      logger.context(klass: klass, item: item)
      logger.context(version: version, item: nil)

      expect(logger.send(:klass)).to eq(klass)
      expect(logger.send(:version)).to eq(version)
      expect(logger.send(:item)).to be_nil
    end

    it 'returns self for method chaining' do
      result = logger.context(klass: klass)

      expect(result).to be_a(described_class)
    end
  end

  describe '#default_attributes' do
    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:item, freeze: false) { create(:ai_catalog_item, id: 1) }
    let_it_be(:version, freeze: false) do
      create(:ai_catalog_item_version, id: 3, schema_version: 1, version: '1.2.0', item: item)
    end

    let_it_be(:consumer) do
      build_stubbed(:ai_catalog_item_consumer, id: 4, project_id: 5, group_id: 6, item: item,
        parent_item_consumer_id: 7, pinned_version_prefix: '1.2.0', service_account_id: 8)
    end

    subject(:default_attributes) { logger.default_attributes }

    it 'includes attributes when set via context' do
      logger.context(klass: 'MyClass', item: item, version: version, consumer: consumer)

      is_expected.to eq({
        feature_category: :workflow_catalog,
        Labkit::Fields::CLASS_NAME => 'MyClass',
        item_id: 1,
        item_project_id: item.project_id,
        item_item_type: item.item_type,
        version_id: 3,
        version_schema_version: 1,
        version_version: '1.2.0',
        consumer_id: 4,
        consumer_project_id: 5,
        consumer_group_id: 6,
        consumer_parent_item_consumer_id: 7,
        consumer_service_account_id: 8,
        consumer_pinned_version_prefix: '1.2.0'
      })
    end

    it 'derives item from consumer when item not directly set' do
      logger.context(consumer: consumer)

      is_expected.to include(item_id: item.id)
    end

    it 'derives item from version when item not directly set' do
      logger.context(version: version)

      is_expected.to include(item_id: item.id)
    end

    it 'derives version from consumer when version not directly set' do
      allow(item).to receive(:resolve_version).and_return(version)

      logger.context(consumer: consumer)

      is_expected.to include(version_id: version.id)
    end
  end

  describe 'logging methods' do
    %i[info error debug warn].each do |level|
      describe "##{level}" do
        it 'merges options with message and calls super' do
          expect_next_instance_of(Gitlab::JsonLogger) do |instance|
            expect(instance).to receive(level).with(hash_including(
              message: 'Test message',
              extra: 'foo'
            ))
          end

          logger.send(level, message: 'Test message', extra: 'foo')
        end

        it 'includes default_attributes in the log output', :aggregate_failures do
          output = StringIO.new
          log = described_class.new(output)

          item = build_stubbed(:ai_catalog_item, id: 10, project_id: 20)
          log.context(klass: 'MyClass', item: item)

          log.send(level, message: 'Test message', extra: 'foo')

          log_entry = Gitlab::Json.safe_parse(output.string)
          expect(log_entry['feature_category']).to eq('workflow_catalog')
          expect(log_entry['class_name']).to eq('MyClass')
          expect(log_entry['item_id']).to eq(10)
          expect(log_entry['item_project_id']).to eq(20)
          expect(log_entry['message']).to eq('Test message')
          expect(log_entry['extra']).to eq('foo')
        end
      end
    end
  end
end
