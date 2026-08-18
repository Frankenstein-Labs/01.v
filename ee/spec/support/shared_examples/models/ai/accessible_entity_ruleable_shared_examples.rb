# frozen_string_literal: true

RSpec.shared_examples 'accessible entity ruleable' do
  describe 'validations' do
    subject { described_class.new }

    it { is_expected.not_to validate_presence_of(:through_namespace_id) }
    it { is_expected.to validate_presence_of(:accessible_entity) }
    it { is_expected.to validate_length_of(:accessible_entity).is_at_most(255) }

    describe 'accessible_entity inclusion validation' do
      context 'with valid access entity' do
        %w[duo_classic duo_agent_platform].each do |entity|
          it "accepts #{entity}" do
            record = described_class.new(accessible_entity: entity)
            expect(record.errors[:accessible_entity]).to be_empty
          end
        end
      end

      context 'with invalid access entity' do
        it 'adds error' do
          record = described_class.new(accessible_entity: 'invalid_entity')
          expect(record).not_to be_valid
          expect(record.errors[:accessible_entity]).to include('is not included in the list')
        end
      end
    end

    describe 'accessible_entity uniqueness validation' do
      context 'when through_namespace_id is present' do
        it 'rejects duplicate accessible_entity for the same through_namespace' do
          create_args = { through_namespace: through_namespace, accessible_entity: 'duo_classic' }
          create_args[:root_namespace] = root_namespace if described_class.column_names.include?('root_namespace_id')

          described_class.create!(create_args.merge(created_at: Time.current, updated_at: Time.current))

          duplicate = described_class.new(create_args)
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:accessible_entity]).to include('has already been taken')
        end
      end
    end
  end

  describe 'BulkInsertSafe inclusion' do
    it 'includes BulkInsertSafe' do
      expect(described_class.included_modules).to include(BulkInsertSafe)
    end
  end
end
