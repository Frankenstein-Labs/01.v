# frozen_string_literal: true

RSpec.shared_examples 'a batch reminder service processing secrets' do |resource_type|
  # Note: The including spec must define:
  # - secret_1, secret_2: secrets with rotation_info created via create_<resource_type>_secret
  # - owner1, owner2: owners of secret_1 and secret_2's resource
  # - resource1, resource2: the project or group owning secret_1 and secret_2
  # - secrets_manager1, secrets_manager2: the secrets managers for resource1 and resource2
  # - mail_name: the mailer method name (e.g. "project_secret_rotation_reminder_email")
  # - rotation_info_class: the rotation info AR class

  context 'when there are no secrets needing reminders' do
    it 'returns zero processed count' do
      expect(result).to eq(processed_count: 0, skipped_count: 0)
      expect_no_delivery_jobs
    end
  end

  context 'with batch size limit' do
    before do
      secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      secret_2.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      stub_const('SecretsManagement::BaseSecretRotationBatchReminderService::BATCH_SIZE', 1)
    end

    it 'processes only batch size number of records' do
      expect(result).to eq(processed_count: 1, skipped_count: 0)
      expect_delivery_jobs_count(1)
    end
  end

  context "when there are #{resource_type} secrets needing reminders" do
    before do
      secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      secret_2.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
    end

    it "processes all eligible #{resource_type} secrets" do
      expect(result).to eq(processed_count: 2, skipped_count: 0)

      expect_delivery_jobs_count(2)
      expect_enqueud_email(owner1.id, resource1.id, secret_1.name, mail: mail_name)
      expect_enqueud_email(owner2.id, resource2.id, secret_2.name, mail: mail_name)

      secret_1.rotation_info.reload
      secret_2.rotation_info.reload

      expect(secret_1.rotation_info.last_reminder_at).to be_present
      expect(secret_1.rotation_info.next_reminder_at).to be_future
      expect(secret_2.rotation_info.last_reminder_at).to be_present
      expect(secret_2.rotation_info.next_reminder_at).to be_future
    end
  end

  context "when there are orphaned #{resource_type} rotation records with a version mismatch" do
    let!(:version_mismatch_rotation_info) do
      create(:"#{resource_type}_secret_rotation_info",
        resource_type.to_sym => resource1,
        secret_name: secret_1.name,
        rotation_interval_days: 30,
        next_reminder_at: 10.minutes.ago,
        last_reminder_at: nil,
        secret_metadata_version: 99
      )
    end

    before do
      secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
    end

    it "cleans up the version-mismatched record and processes the valid one" do
      expect(result).to eq(processed_count: 1, skipped_count: 1)

      expect_delivery_jobs_count(1)
      expect_enqueud_email(owner1.id, resource1.id, secret_1.name, mail: mail_name)

      expect(rotation_info_class.exists?(version_mismatch_rotation_info.id)).to be_falsey
    end
  end

  context "when the #{resource_type} has no secrets manager" do
    before do
      secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      resource1.secrets_manager.destroy!
      resource1.reload
    end

    it "cleans up the orphaned rotation record" do
      expect(result).to eq(processed_count: 0, skipped_count: 1)

      expect_no_delivery_jobs
      expect(rotation_info_class.exists?(secret_1.rotation_info.id)).to be_falsey
    end
  end

  context "when there are orphaned #{resource_type} rotation records" do
    let!(:orphaned_rotation_info) do
      create(:"#{resource_type}_secret_rotation_info",
        resource_type.to_sym => resource1,
        secret_name: 'DELETED_SECRET',
        rotation_interval_days: 30,
        next_reminder_at: 10.minutes.ago,
        last_reminder_at: nil
      )
    end

    before do
      secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      secret_2.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)

      secrets_manager2.initiate_deprovision!
    end

    it "processes valid #{resource_type} secrets and cleans up orphaned records" do
      expect(result).to eq(processed_count: 1, skipped_count: 2)

      expect_delivery_jobs_count(1)
      expect_enqueud_email(owner1.id, resource1.id, secret_1.name, mail: mail_name)

      secret_1.rotation_info.reload
      expect(secret_1.rotation_info.last_reminder_at).to be_present
      expect(secret_1.rotation_info.next_reminder_at).to be_future

      expect(rotation_info_class.exists?(secret_2.rotation_info.id)).to be_falsey
      expect(rotation_info_class.exists?(orphaned_rotation_info.id)).to be_falsey
    end
  end
end
