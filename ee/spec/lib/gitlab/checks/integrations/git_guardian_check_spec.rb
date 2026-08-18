# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::Integrations::GitGuardianCheck, feature_category: :source_code_management do
  include_context 'changes access checks context'

  let_it_be(:oldrev) { 'e63f41fe459e62e1228fcef60d7189127aeba95a' }
  let_it_be(:newrev) { 'e774ebd33ca5de8e6ef1e633fd887bb52b9d0a7a' }

  let(:integration_check) { Gitlab::Checks::IntegrationsCheck.new(changes_access) }
  let(:project_repository_url) { Gitlab::Checks::Integrations::GitGuardianProjectUrlHeader.build(project) }

  before_all do
    project.repository.delete_branch('add-pdf-file')
  end

  subject(:git_guardian_check) { described_class.new(integration_check) }

  describe '#validate!' do
    context 'when integration is not set up' do
      it 'does not validate the blobs' do
        expect(::Gitlab::GitGuardian::Client).not_to receive(:new)

        expect { git_guardian_check.validate! }.not_to raise_error
      end
    end

    context 'when integration is set up' do
      let(:integration_active) { true }

      before do
        create(:git_guardian_integration, active: integration_active, project: project)
      end

      context 'when integration is not active' do
        let(:integration_active) { false }

        it 'does not validate the blobs' do
          expect(::Gitlab::GitGuardian::Client).not_to receive(:new)

          expect(described_class).not_to receive(:format_git_guardian_response)
        end
      end

      context 'when integration is active' do
        it 'does not raise any error if no policy was broken' do
          expect_next_instance_of(::Gitlab::GitGuardian::Client) do |client|
            expect(client).to receive(:execute) do |blobs, repository_url|
              expect(blobs.size).to eq(1)

              blob = blobs.first
              expect(blob).to be_kind_of(Gitlab::Git::Blob)
              expect(blob.path).to eq('files/pdf/test.pdf')

              expect(repository_url).to eq(project_repository_url)
            end.and_return([])
          end

          expect { git_guardian_check.validate! }.not_to raise_error
        end

        it 'filters out the large blobs' do
          expect_next_instance_of(::Gitlab::GitGuardian::Client) do |client|
            expect(client).to receive(:execute).with([], project_repository_url).and_return([])
          end

          stub_const("#{described_class}::BLOB_BYTES_LIMIT", 1)

          expect { git_guardian_check.validate! }.not_to raise_error
        end

        it 'propagates the API error' do
          expect_next_instance_of(::Gitlab::GitGuardian::Client) do |client|
            expect(client).to receive(:execute).and_raise(
              Gitlab::GitGuardian::Client::RequestError, '401 Unauthorized'
            )
          end

          expect { git_guardian_check.validate! }.to raise_error(
            ::Gitlab::GitAccess::ForbiddenError, 'GitGuardian API error: 401 Unauthorized'
          )
        end

        context 'when policies were broken' do
          let(:policy_breaks) do
            [
              <<~POLICY_BREAK
              .env: 2 incidents detected:

               >> Filenames: .env
                  Validity: N/A
                  Known by GitGuardian: No
                  Incident URL: N/A
                  Violation: filename `.env` detected
              POLICY_BREAK
            ]
          end

          let(:policy_breaks_message) { policy_breaks.join(",\n") }

          it 'does raise an error' do
            expect_next_instance_of(::Gitlab::GitGuardian::Client) do |client|
              expect(client).to receive(:execute) do |blobs, repository_url|
                expect(blobs.size).to eq(1)

                blob = blobs.first
                expect(blob).to be_kind_of(Gitlab::Git::Blob)
                expect(blob.path).to eq('files/pdf/test.pdf')

                expect(repository_url).to eq(project_repository_url)
              end.and_return(policy_breaks)
            end

            expect { git_guardian_check.validate! }
              .to raise_error(::Gitlab::GitAccess::ForbiddenError,
                policy_breaks_message + described_class::REMEDIATION_MESSAGE)
          end

          context 'when a commit contains a special flag' do
            it 'does not raise an error when the flag is skip secret detection' do
              expect(::Gitlab::GitGuardian::Client).not_to receive(:new)

              allow(changes_access.commits.first).to receive(:safe_message).and_return(
                "#{changes_access.commits.first.safe_message}\n[skip secret detection]"
              )

              expect { git_guardian_check.validate! }.not_to raise_error
            end

            it 'does not raise an error when the flag is skip secret push protection' do
              expect(::Gitlab::GitGuardian::Client).not_to receive(:new)

              allow(changes_access.commits.first).to receive(:safe_message).and_return(
                "#{changes_access.commits.first.safe_message}\n[skip secret push protection]"
              )

              expect { git_guardian_check.validate! }.not_to raise_error
            end
          end

          context 'when secret_detection.skip_all push option is passed' do
            let(:push_options) { Gitlab::PushOptions.new(["secret_detection.skip_all"]) }

            it 'does not raise an error' do
              expect(::Gitlab::GitGuardian::Client).not_to receive(:new)

              expect { git_guardian_check.validate! }.not_to raise_error
            end
          end

          context 'when secret_push_protection.skip_all push option is passed' do
            let(:push_options) { Gitlab::PushOptions.new(["secret_push_protection.skip_all"]) }

            it 'does not raise an error' do
              expect(::Gitlab::GitGuardian::Client).not_to receive(:new)

              expect { git_guardian_check.validate! }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
