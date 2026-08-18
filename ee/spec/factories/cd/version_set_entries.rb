# frozen_string_literal: true

FactoryBot.define do
  factory :cd_version_set_entry, class: 'Cd::VersionSetEntry' do
    version_set { association(:cd_version_set) }
    version do
      service = association(:cd_service, application: version_set.application)
      artifact_source = association(:cd_artifact_source, service: service)
      association(:cd_version, artifact_source: artifact_source)
    end
  end
end
