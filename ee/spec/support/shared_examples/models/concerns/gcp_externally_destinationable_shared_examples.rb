# frozen_string_literal: true

RSpec.shared_examples 'includes GcpExternallyDestinationable concern' do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:google_project_id_name) }
    it { is_expected.to validate_presence_of(:client_email) }
    it { is_expected.to validate_presence_of(:log_id_name) }
    it { is_expected.to validate_presence_of(:private_key) }

    it { is_expected.to validate_length_of(:google_project_id_name).is_at_least(6).is_at_most(30) }
    it { is_expected.to validate_length_of(:client_email).is_at_most(254) }
    it { is_expected.to validate_length_of(:log_id_name).is_at_most(511) }
    it { is_expected.to validate_length_of(:name).is_at_most(72) }

    it { is_expected.to allow_value('valid-project-id').for(:google_project_id_name) }
    it { is_expected.to allow_value('valid-project-id-1').for(:google_project_id_name) }
    it { is_expected.not_to allow_value('invalid_project_id').for(:google_project_id_name) }
    it { is_expected.not_to allow_value('invalid-project-id-').for(:google_project_id_name) }
    it { is_expected.not_to allow_value('Invalid-project-id').for(:google_project_id_name) }
    it { is_expected.not_to allow_value('1-invalid-project-id').for(:google_project_id_name) }
    it { is_expected.not_to allow_value('-invalid-project-id-1').for(:google_project_id_name) }

    it { is_expected.to allow_value('valid@example.com').for(:client_email) }
    it { is_expected.to allow_value('valid@example.org').for(:client_email) }
    it { is_expected.to allow_value('valid@example.co.uk').for(:client_email) }
    it { is_expected.to allow_value('valid_email+mail@mail.com').for(:client_email) }
    it { is_expected.not_to allow_value('invalid_email').for(:client_email) }
    it { is_expected.not_to allow_value('invalid@.com').for(:client_email) }
    it { is_expected.not_to allow_value('invalid..com').for(:client_email) }

    it { is_expected.to allow_value('audit_events').for(:log_id_name) }
    it { is_expected.to allow_value('audit-events').for(:log_id_name) }
    it { is_expected.to allow_value('audit.events').for(:log_id_name) }
    it { is_expected.to allow_value('AUDIT_EVENTS').for(:log_id_name) }
    it { is_expected.to allow_value('audit_events/123').for(:log_id_name) }
    it { is_expected.not_to allow_value('AUDIT_EVENT@').for(:log_id_name) }
    it { is_expected.not_to allow_value('AUDIT_EVENT$').for(:log_id_name) }
    it { is_expected.not_to allow_value('#AUDIT_EVENT').for(:log_id_name) }
    it { is_expected.not_to allow_value('%audit_events/123').for(:log_id_name) }

    describe 'default values' do
      it "uses 'audit_events' as default value for log_id_name" do
        expect(described_class.new.log_id_name).to eq('audit_events')
      end
    end

    describe '#allowed_to_stream?' do
      it 'always returns true' do
        expect(subject.allowed_to_stream?).to eq(true)
      end
    end

    describe '#full_log_path' do
      it 'returns the full log path for the google project' do
        subject.google_project_id_name = "test-project"
        subject.log_id_name = "test-log"

        expect(subject.full_log_path).to eq("projects/test-project/logs/test-log")
      end
    end
  end
end
