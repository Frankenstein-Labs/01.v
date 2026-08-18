# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::EligibilityChecker, feature_category: :secret_detection do
  include_context 'secrets check context'

  let(:validator) do
    described_class.new(
      project: project,
      changes_access: changes_access
    )
  end

  describe '#should_scan?' do
    shared_examples 'skips the push check' do
      it 'returns false' do
        expect(validator.should_scan?).to be(false)
      end
    end

    shared_examples 'performs the push check' do
      it 'returns true' do
        expect(validator.should_scan?).to be(true)
      end
    end

    context 'when application setting is disabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: false)
      end

      it_behaves_like 'skips the push check'
    end

    context 'when application setting is enabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: true)
      end

      context 'when project setting is disabled' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: false)
        end

        context 'when secret push protection is enforced at instance-level' do
          before do
            Gitlab::CurrentSettings.update!(secret_push_protection_enforced: true)
          end

          context 'when project has Ultimate license' do
            before do
              stub_licensed_features(secret_push_protection: true)
            end

            it_behaves_like 'performs the push check'
          end
        end

        context 'when project has Ultimate license' do
          let(:additional_licensed_features) { {} }

          before do
            stub_licensed_features({ secret_push_protection: true }.merge(additional_licensed_features))
          end

          it_behaves_like 'skips the push check'

          context 'when project has a secret_detection scan profile' do
            let_it_be(:secret_detection_profile) do
              create(:security_scan_profile,
                namespace: project.namespace,
                scan_type: :secret_detection,
                name: 'Secret Detection Profile')
            end

            let_it_be(:profile_project_association) do
              create(:security_scan_profile_project,
                scan_profile: secret_detection_profile,
                project: project)
            end

            context 'when security_scan_profiles licensed feature is not available' do
              let(:additional_licensed_features) { { security_scan_profiles: false } }

              it_behaves_like 'skips the push check'
            end

            context 'when security_scan_profiles licensed feature is available' do
              let(:additional_licensed_features) { { security_scan_profiles: true } }

              context 'and feature flag is disabled' do
                before do
                  stub_feature_flags(security_scan_profiles_feature: false)
                end

                it_behaves_like 'skips the push check'
              end

              context 'when scan profile does not have git_push_event trigger' do
                it_behaves_like 'skips the push check'
              end

              context 'when scan profile has git_push_event trigger' do
                let_it_be(:trigger) do
                  create(:security_scan_profile_trigger,
                    namespace: project.namespace,
                    scan_profile: secret_detection_profile,
                    trigger_type: :git_push_event)
                end

                it_behaves_like 'performs the push check'
              end

              context 'when scan profile has a different trigger type' do
                let_it_be(:trigger) do
                  create(:security_scan_profile_trigger,
                    namespace: project.namespace,
                    scan_profile: secret_detection_profile,
                    trigger_type: :default_branch_pipeline)
                end

                it_behaves_like 'skips the push check'
              end
            end
          end

          context 'when project has a non secret_detection scan profile' do
            let_it_be(:sast_profile) do
              create(:security_scan_profile,
                namespace: project.namespace,
                scan_type: :sast,
                name: 'SAST Profile')
            end

            let_it_be(:profile_project_association) do
              create(:security_scan_profile_project, scan_profile: sast_profile, project: project)
            end

            context 'when security_scan_profiles licensed feature' do
              let(:additional_licensed_features) { { security_scan_profiles: true } }

              it_behaves_like 'skips the push check'
            end
          end
        end
      end

      context 'when project setting is enabled' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: true)
        end

        context 'when license is not ultimate' do
          it_behaves_like 'skips the push check'
        end

        context 'when license is ultimate' do
          before do
            stub_licensed_features(secret_push_protection: true)
          end

          context 'when this commit is deleting the branch' do
            let(:changes) do
              [
                { oldrev: new_commit, newrev: Gitlab::Git::SHA1_BLANK_SHA, ref: 'refs/heads/deleteme' }
              ]
            end

            it_behaves_like 'skips the push check'
          end

          context 'when commit message contains skip flag' do
            let_it_be(:new_commit) do
              create_commit(
                { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' }, # gitleaks:allow
                'skip scan [skip secret push protection]'
              )
            end

            it_behaves_like 'skips the push check'
          end

          context 'when push option skips secret detection' do
            let(:changes_access) do
              ::Gitlab::Checks::ChangesAccess.new(
                changes,
                project: project,
                user_access: user_access,
                protocol: protocol,
                logger: logger,
                push_options: ::Gitlab::PushOptions.new(["secret_push_protection.skip_all"]),
                gitaly_context: gitaly_context
              )
            end

            it_behaves_like 'skips the push check'
          end

          context 'when all checks pass' do
            it_behaves_like 'performs the push check'
          end
        end
      end
    end
  end
end
