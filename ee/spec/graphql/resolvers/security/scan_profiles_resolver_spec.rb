# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::ScanProfilesResolver, feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }
  let(:args) { {} }

  let(:current_user) { user }

  subject(:resolve_scan_profiles) do
    resolve(described_class, obj: group, args: args, ctx: { current_user: current_user })
  end

  before_all do
    root_group.add_developer(user)
  end

  def default_profile_by_type(type)
    ::Security::DefaultScanProfilesHelper.default_scan_profiles
      .find { |p| p.scan_type == type.to_s }
  end

  describe '#resolve' do
    context 'when security_scan_profiles feature is not available' do
      let(:group) { root_group }

      it 'raises an authorization error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve_scan_profiles
        end
      end
    end

    context 'when security_scan_profiles feature is available' do
      before do
        stub_licensed_features(security_scan_profiles: true)
      end

      context 'when user does not have permission' do
        let(:group) { root_group }
        let(:current_user) { create(:user) }

        it 'raises an authorization error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            resolve_scan_profiles
          end
        end
      end

      context 'when user has permission' do
        context 'when resolving from root group' do
          let(:group) { root_group }

          context 'without type argument' do
            let(:args) { {} }

            context 'when there are no persisted scan profiles' do
              it 'returns only default scan profiles' do
                profiles = resolve_scan_profiles
                default_profiles = ::Security::DefaultScanProfilesHelper.default_scan_profiles

                expect(profiles.size).to eq(default_profiles.size)

                default_profiles.each do |default|
                  matching_profile = profiles.find { |p| p.scan_type == default.scan_type }
                  expect(matching_profile).to have_attributes(
                    scan_type: default.scan_type,
                    name: default.name,
                    description: default.description,
                    gitlab_recommended: default.gitlab_recommended,
                    namespace_id: root_group.id
                  )
                end
              end
            end

            context 'when there are persisted profiles without gitlab_recommended' do
              let_it_be(:custom_profile) do
                create(:security_scan_profile,
                  namespace: root_group,
                  scan_type: :sast,
                  name: 'Custom SAST',
                  gitlab_recommended: false)
              end

              it 'returns both persisted and default scan profiles' do
                profiles = resolve_scan_profiles
                default_profiles = ::Security::DefaultScanProfilesHelper.default_scan_profiles

                expect(profiles.size).to eq(default_profiles.size + 1)
                expect(profiles).to include(custom_profile)
                expect(profiles.map(&:scan_type)).to match_array(default_profiles.map(&:scan_type) + %w[sast])
              end
            end

            context 'when there is a persisted gitlab_recommended profile' do
              let_it_be(:recommended_secret_detection) do
                create(:security_scan_profile,
                  namespace: root_group,
                  scan_type: :secret_detection,
                  name: 'Persisted Secret Detection (default)',
                  gitlab_recommended: true)
              end

              let(:args) { { type: 'secret_detection' } }

              it 'returns only the persisted profile without the default' do
                profiles = resolve_scan_profiles
                default_secret_detection = default_profile_by_type(:secret_detection)

                expect(profiles).to contain_exactly(recommended_secret_detection)
                expect(profiles.map(&:name)).not_to include(default_secret_detection.name)
              end
            end

            context 'when there are multiple persisted profiles without gitlab_recommended' do
              let_it_be(:sast_profile) do
                create(:security_scan_profile,
                  namespace: root_group,
                  scan_type: :sast,
                  name: 'SAST Profile',
                  gitlab_recommended: false)
              end

              it 'returns all persisted profiles and defaults for types without recommended profiles' do
                profiles = resolve_scan_profiles
                default_profiles = ::Security::DefaultScanProfilesHelper.default_scan_profiles

                expect(profiles).to include(sast_profile)
                expect(profiles.map(&:scan_type)).to match_array(default_profiles.map(&:scan_type) + %w[sast])
              end
            end
          end

          context 'with type argument' do
            context 'when filtering by secret_detection' do
              let(:args) { { type: 'secret_detection' } }

              context 'when there are no persisted profiles of that type' do
                let_it_be(:sast_profile) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :sast,
                    name: 'SAST Profile')
                end

                it 'returns only the default secret_detection profile' do
                  profiles = resolve_scan_profiles
                  default_secret_detection = default_profile_by_type(:secret_detection)

                  expect(profiles.size).to eq(1)
                  expect(profiles.first).to have_attributes(
                    scan_type: default_secret_detection.scan_type,
                    name: default_secret_detection.name,
                    description: default_secret_detection.description,
                    gitlab_recommended: default_secret_detection.gitlab_recommended
                  )
                end
              end

              context 'when there is a persisted gitlab_recommended profile of that type' do
                let_it_be(:recommended_secret_detection) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :secret_detection,
                    name: 'Persisted Secret Detection (default)',
                    gitlab_recommended: true)
                end

                it 'returns only the recommended profile without the default' do
                  profiles = resolve_scan_profiles

                  expect(profiles).to contain_exactly(recommended_secret_detection)
                end
              end

              context 'when there is a persisted custom profile of that type' do
                let_it_be(:custom_secret_detection) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :secret_detection,
                    name: 'Custom Secret Detection',
                    gitlab_recommended: false)
                end

                it 'returns both the default profile and custom profiles' do
                  default_secret_detection = default_profile_by_type(:secret_detection)
                  profiles = resolve_scan_profiles

                  expect(profiles.size).to eq(2)
                  expect(profiles).to include(custom_secret_detection)
                  expect(profiles.map(&:name)).to match_array([
                    custom_secret_detection.name, default_secret_detection.name
                  ])
                end
              end
            end
          end

          context 'with gitlab_recommended argument' do
            context 'when filtering for gitlab_recommended: true' do
              let(:args) { { gitlab_recommended: true } }

              context 'when there are no persisted profiles' do
                it 'returns only default profiles' do
                  profiles = resolve_scan_profiles
                  default_profiles = ::Security::DefaultScanProfilesHelper.default_scan_profiles

                  expect(profiles.size).to eq(default_profiles.size)
                  expect(profiles).to all(have_attributes(gitlab_recommended: true))
                end
              end

              context 'when there are mixed persisted profiles' do
                let_it_be(:recommended_sast) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :sast,
                    name: 'Recommended SAST',
                    gitlab_recommended: true)
                end

                let_it_be(:custom_sast) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :sast,
                    name: 'Custom SAST',
                    gitlab_recommended: false)
                end

                it 'returns only gitlab_recommended profiles' do
                  profiles = resolve_scan_profiles

                  expect(profiles).to include(recommended_sast)
                  expect(profiles).not_to include(custom_sast)
                  expect(profiles).to all(have_attributes(gitlab_recommended: true))
                end
              end
            end

            context 'when filtering for gitlab_recommended: false' do
              let(:args) { { gitlab_recommended: false } }

              context 'when there are no persisted profiles' do
                it 'returns empty array' do
                  profiles = resolve_scan_profiles

                  expect(profiles).to be_empty
                end
              end

              context 'when there are mixed persisted profiles' do
                let_it_be(:recommended_sast) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :sast,
                    name: 'Recommended SAST',
                    gitlab_recommended: true)
                end

                let_it_be(:custom_sast) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :sast,
                    name: 'Custom SAST',
                    gitlab_recommended: false)
                end

                let_it_be(:custom_secret_detection) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :secret_detection,
                    name: 'Custom Secret Detection',
                    gitlab_recommended: false)
                end

                it 'returns only non-recommended profiles without defaults' do
                  profiles = resolve_scan_profiles

                  expect(profiles).to contain_exactly(custom_sast, custom_secret_detection)
                  expect(profiles).to all(have_attributes(gitlab_recommended: false))
                end
              end
            end
          end

          context 'with both type and gitlab_recommended arguments' do
            let_it_be(:recommended_sast) do
              create(:security_scan_profile,
                namespace: root_group,
                scan_type: :sast,
                name: 'Recommended SAST',
                gitlab_recommended: true)
            end

            let_it_be(:custom_sast) do
              create(:security_scan_profile,
                namespace: root_group,
                scan_type: :sast,
                name: 'Custom SAST',
                gitlab_recommended: false)
            end

            let_it_be(:recommended_secret_detection) do
              create(:security_scan_profile,
                namespace: root_group,
                scan_type: :secret_detection,
                name: 'Recommended Secret Detection',
                gitlab_recommended: true)
            end

            let_it_be(:custom_secret_detection) do
              create(:security_scan_profile,
                namespace: root_group,
                scan_type: :secret_detection,
                name: 'Custom Secret Detection',
                gitlab_recommended: false)
            end

            context 'when filtering for type: sast and gitlab_recommended: true' do
              let(:args) { { type: 'sast', gitlab_recommended: true } }

              it 'returns only gitlab_recommended profiles of the specified type' do
                profiles = resolve_scan_profiles

                expect(profiles).to contain_exactly(recommended_sast)
                expect(profiles).to all(have_attributes(
                  scan_type: 'sast',
                  gitlab_recommended: true
                ))
              end
            end

            context 'when filtering for type: secret_detection and gitlab_recommended: false' do
              let(:args) { { type: 'secret_detection', gitlab_recommended: false } }

              it 'returns only custom profiles of the specified type without defaults' do
                profiles = resolve_scan_profiles

                expect(profiles).to contain_exactly(custom_secret_detection)
                expect(profiles).to all(have_attributes(
                  scan_type: 'secret_detection',
                  gitlab_recommended: false
                ))
              end
            end
          end
        end

        context 'with the post-processing default profile' do
          let(:group) { root_group }

          it 'includes the post-processing default profile' do
            profiles = resolve_scan_profiles

            expect(profiles.map(&:scan_type)).to include('dependency_scanning_post_processing')
          end

          context 'when security_remediation_profiles feature flag is disabled' do
            before do
              stub_feature_flags(security_remediation_profiles: false)
            end

            it 'hides the post-processing default profile' do
              profiles = resolve_scan_profiles

              expect(profiles.map(&:scan_type)).not_to include('dependency_scanning_post_processing')
            end

            it 'still returns the scanner default profiles' do
              profiles = resolve_scan_profiles

              expect(profiles.map(&:scan_type)).to match_array(%w[secret_detection sast dependency_scanning])
            end
          end
        end

        context 'when resolving from subgroup' do
          let(:group) { subgroup }

          it 'uses root ancestor for fetching profiles' do
            profiles = resolve_scan_profiles

            expect(profiles.first.namespace_id).to eq(root_group.id)
          end
        end
      end
    end
  end
end
