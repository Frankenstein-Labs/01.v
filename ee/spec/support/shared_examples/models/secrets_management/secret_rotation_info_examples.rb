# frozen_string_literal: true

RSpec.shared_examples 'a secret rotation info' do
  # Expected let variables:
  #   rotation_info_factory  - e.g. :project_secret_rotation_info or :group_secret_rotation_info
  #   parent                 - the project or group instance
  #   other_parent           - another project or group instance (for .for_secret isolation test)
  #   parent_association     - e.g. :project or :group

  describe 'validations' do
    subject { build(rotation_info_factory) }

    it { is_expected.to validate_presence_of(:secret_name) }
    it { is_expected.to validate_presence_of(:rotation_interval_days) }
    it { is_expected.to validate_presence_of(:secret_metadata_version) }
    it { is_expected.to validate_presence_of(:next_reminder_at) }
    it { is_expected.to validate_length_of(:secret_name).is_at_most(255) }
    it { is_expected.to validate_numericality_of(:rotation_interval_days).is_greater_than_or_equal_to(7) }
  end

  describe 'scopes' do
    describe '.pending_reminders', :freeze_time do
      let!(:pending_reminder) do
        create(rotation_info_factory, parent_association => parent, next_reminder_at: 1.hour.ago)
      end

      let!(:older_reminder) do
        create(rotation_info_factory, parent_association => parent, next_reminder_at: 2.hours.ago)
      end

      let!(:future_reminder) do
        create(rotation_info_factory, parent_association => parent, next_reminder_at: 1.day.from_now)
      end

      let!(:due_now_reminder) do
        create(rotation_info_factory, parent_association => parent, next_reminder_at: Time.current)
      end

      it 'returns records with next_reminder_at in the past or present' do
        result = described_class.pending_reminders

        expect(result).to eq([older_reminder, pending_reminder, due_now_reminder])
      end
    end
  end

  describe '.for_secret' do
    let!(:rotation_info) do
      create(rotation_info_factory,
        parent_association => parent,
        secret_name: 'TEST_SECRET',
        secret_metadata_version: 1
      )
    end

    let!(:other_rotation_info) do
      create(rotation_info_factory,
        parent_association => other_parent,
        secret_name: 'TEST_SECRET',
        secret_metadata_version: 1
      )
    end

    it 'returns the correct rotation info' do
      result = described_class.for_secret(parent, 'TEST_SECRET', 1)

      expect(result).to eq(rotation_info)
      expect(result).not_to eq(other_rotation_info)
    end

    it 'returns nil when no matching record exists' do
      result = described_class.for_secret(parent, 'NONEXISTENT', 1)

      expect(result).to be_nil
    end
  end

  describe '#upsert', :aggregate_failures do
    let(:secret_name) { 'TEST_SECRET' }
    let(:rotation_interval_days) { 30 }
    let(:secret_metadata_version) { 1 }

    let(:rotation_info) do
      build(rotation_info_factory,
        parent_association => parent,
        secret_name: secret_name,
        rotation_interval_days: rotation_interval_days,
        secret_metadata_version: secret_metadata_version
      )
    end

    subject(:result) { rotation_info.upsert }

    context 'when the record is valid' do
      context 'and no existing record exists' do
        it 'creates a new record and sets the correct attributes' do
          travel_to(Time.zone.parse('2025-09-03 22:00:00 UTC')) do
            expect { result }.to change { described_class.count }.by(1)
            expect(result).to be_truthy
            expect(rotation_info.id).to be_present

            saved_record = described_class.find(rotation_info.id)
            expect(saved_record.public_send(parent_association)).to eq(parent)
            expect(saved_record.secret_name).to eq(secret_name)
            expect(saved_record.secret_metadata_version).to eq(secret_metadata_version)
            expect(saved_record.rotation_interval_days).to eq(rotation_interval_days)
            expect(saved_record.last_reminder_at).to be_nil

            expected_time = Time.zone.parse('2025-10-04 00:00:00 UTC')
            expect(saved_record.next_reminder_at).to eq(expected_time)
          end
        end
      end

      context 'and an existing record exists with same unique keys' do
        let!(:existing_record) do
          create(rotation_info_factory,
            parent_association => parent,
            secret_name: secret_name,
            secret_metadata_version: secret_metadata_version,
            rotation_interval_days: 60
          )
        end

        it 'updates the existing record' do
          travel_to(Time.parse('2025-09-03 22:00:00 UTC')) do
            expect { result }.not_to change { described_class.count }
            expect(result).to be_truthy
            expect(rotation_info.id).to be_present

            saved_record = described_class.find(rotation_info.id)
            expect(saved_record).to eq(existing_record)

            expect(saved_record.public_send(parent_association)).to eq(parent)
            expect(saved_record.secret_name).to eq(secret_name)
            expect(saved_record.secret_metadata_version).to eq(secret_metadata_version)
            expect(saved_record.rotation_interval_days).to eq(rotation_interval_days)
            expect(saved_record.last_reminder_at).to be_nil

            expected_time = Time.parse('2025-10-04 00:00:00 UTC')
            expect(saved_record.next_reminder_at).to eq(expected_time)
          end
        end
      end
    end

    context 'when the record is invalid' do
      let(:rotation_interval_days) { 3 }

      it 'returns false and does not create a record' do
        expect { result }.not_to change { described_class.count }
        expect(result).to be_falsey

        expect(rotation_info.errors[:rotation_interval_days]).to include('must be greater than or equal to 7')
      end
    end
  end

  describe '#notification_sent!', :aggregate_failures do
    it 'updates last_reminder_at to current time and updates next_reminder_at' do
      travel_to(Time.parse('2025-09-03 15:30:00 UTC')) do
        rotation_info = create(rotation_info_factory,
          parent_association => parent,
          rotation_interval_days: 7,
          next_reminder_at: 1.hour.ago,
          last_reminder_at: nil
        )

        expect { rotation_info.notification_sent! }.to change { rotation_info.reload.last_reminder_at }
          .from(nil)
          .to(Time.current)

        expected_time = Time.parse('2025-09-11 00:00:00 UTC')
        expect(rotation_info.reload.next_reminder_at).to eq(expected_time)
      end
    end
  end

  describe '#status', :freeze_time do
    subject { rotation_info.status }

    context 'when secret is overdue (last_reminder_at is present)' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: 1.day.ago,
          next_reminder_at: 1.hour.from_now
        )
      end

      it { is_expected.to eq('OVERDUE') }
    end

    context 'when secret is approaching rotation' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: nil,
          next_reminder_at: 3.days.from_now
        )
      end

      it { is_expected.to eq('APPROACHING') }
    end

    context 'when secret rotation is OK' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: nil,
          next_reminder_at: 10.days.from_now
        )
      end

      it { is_expected.to eq('OK') }
    end

    context 'when next_reminder_at is exactly at the threshold' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: nil,
          next_reminder_at: 7.days.from_now
        )
      end

      it { is_expected.to eq('APPROACHING') }
    end
  end

  describe '#needs_attention?', :freeze_time do
    subject { rotation_info.needs_attention? }

    context 'when overdue' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: 1.day.ago,
          next_reminder_at: 1.hour.from_now
        )
      end

      it { is_expected.to be true }
    end

    context 'when approaching' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: nil,
          next_reminder_at: 3.days.from_now
        )
      end

      it { is_expected.to be true }
    end

    context 'when ok' do
      let(:rotation_info) do
        build(rotation_info_factory,
          parent_association => parent,
          last_reminder_at: nil,
          next_reminder_at: 10.days.from_now
        )
      end

      it { is_expected.to be false }
    end
  end
end
