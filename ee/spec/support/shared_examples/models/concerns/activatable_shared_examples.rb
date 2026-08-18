# frozen_string_literal: true

RSpec.shared_examples 'includes Activatable concern' do
  describe 'active/inactive functionality' do
    let(:valid_model) { create(model_factory_name) } # rubocop:disable Rails/SaveBang -- Just for example

    it { is_expected.to be_a(AuditEvents::Activatable) }

    describe '.active scope' do
      it 'returns only active records' do
        active_model = create(model_factory_name, active: true)
        create(model_factory_name, active: false)

        expect(described_class.active).to contain_exactly(active_model)
      end
    end

    describe '.active_for_scope' do
      context 'when model is group-scoped' do
        next unless described_class.limit_scope == :group

        it 'returns active records for the given scope' do
          group1 = create(:group)
          group2 = create(:group)

          active_model_group1 = create(model_factory_name, active: true, group: group1)
          create(model_factory_name, active: false, group: group1)
          create(model_factory_name, active: true, group: group2)

          expect(described_class.active_for_scope(group1)).to contain_exactly(active_model_group1)
        end
      end
    end

    describe '#active?' do
      it 'returns true for active records' do
        model = create(model_factory_name, active: true)
        expect(model.active?).to be true
      end

      it 'returns false for inactive records' do
        model = create(model_factory_name, active: false)
        expect(model.active?).to be false
      end
    end

    describe '#activate!' do
      it 'sets active to true' do
        model = create(model_factory_name, active: false)

        model.activate!

        expect(model.active).to be true
      end

      context 'when limit validation fails' do
        before do
          plan = Plan.default
          plan.actual_limits.update!(described_class.limit_name => 0)
        end

        it 'raises error with formatted message' do
          model = create(model_factory_name, active: false)
          error_msg = "Cannot activate: Maximum number of " \
            "#{described_class.limit_name.humanize(capitalize: false)} " \
            "(0) exceeded"
          expect { model.activate! }.to raise_error(ActiveRecord::RecordInvalid) do |error|
            expect(error.record.errors[:base]).to include(
              error_msg
            )
          end
        end
      end
    end

    describe '#deactivate!' do
      it 'sets active to false' do
        model = create(model_factory_name, active: true)

        model.deactivate!

        expect(model.active).to be false
      end
    end

    describe '#active_records_for_limit_check' do
      context 'when limit_scope is group' do
        next unless described_class.limit_scope == :group

        it 'returns active records for the model scope' do
          group1 = create(:group)
          group2 = create(:group)

          model = create(model_factory_name, active: false, group: group1)
          active_model_group1 = create(model_factory_name, active: true, group: group1)
          create(model_factory_name, active: true, group: group2)

          expect(model.active_records_for_limit_check).to contain_exactly(active_model_group1)
        end
      end

      context 'when limit_scope is GLOBAL_SCOPE' do
        next unless described_class.limit_scope == Limitable::GLOBAL_SCOPE

        before do
          described_class.delete_all
        end

        it 'returns all active records using self.class.active' do
          model = create(model_factory_name, active: false)
          active_model1 = create(model_factory_name, active: true)
          active_model2 = create(model_factory_name, active: true)
          create(model_factory_name, active: false)

          expect(model.active_records_for_limit_check).to contain_exactly(active_model1, active_model2)
          expect(model.active_records_for_limit_check).to eq(described_class.active.to_a)
        end
      end
    end

    describe '#validate_activation_limit_on_update' do
      let(:limit_value) { 2 }

      before do
        plan = Plan.default
        plan.actual_limits.update!(described_class.limit_name => limit_value)
      end

      context 'when activating a record' do
        it 'allows activation when within limit' do
          if described_class.limit_scope == :group
            group = create(:group)
            create_list(model_factory_name, limit_value - 1, active: false, group: group).each do |record|
              record.update_column(:active, true)
            end
            model = create(model_factory_name, active: false, group: group)
          else
            create_list(model_factory_name, limit_value - 1, active: false).each do |record|
              record.update_column(:active, true)
            end
            model = create(model_factory_name, active: false)
          end

          model.active = true
          expect(model).to be_valid
        end
      end

      context 'when deactivating a record' do
        it 'does not validate activation limit' do
          model = create(model_factory_name, active: false)
          model.update_column(:active, true)
          model.active = false
          expect(model).to be_valid
        end
      end

      context 'when not changing active status' do
        it 'does not validate activation limit' do
          model = create(model_factory_name, active: false)
          model.update_column(:active, true)
          model.name = 'updated name' if model.respond_to?(:name=)
          expect(model).to be_valid
        end
      end
    end

    describe 'limit_relation assignment' do
      it 'sets limit_relation to active_records_for_limit_check' do
        expect(described_class.limit_relation).to eq(:active_records_for_limit_check)
      end
    end
  end
end
