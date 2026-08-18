# frozen_string_literal: true

FactoryBot.define do
  factory :arkose_session, class: 'Users::ArkoseSession' do
    user
    sequence(:session_xid) { "#{SecureRandom.hex(8)}0.#{SecureRandom.hex(5)}" }
    challenge_shown { true }
    challenge_solved { true }
    session_created_at { Time.zone.now - 45.seconds }
    checked_answer_at { Time.zone.now - 15.seconds }
    verified_at { Time.zone.now }
    session_is_legit { true }
    telltale_user { "eng-1362-game3-py-0." }
    # rubocop:disable Layout/LineLength -- user agent full value is long
    user_agent do
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36"
    end
    # rubocop:enable Layout/LineLength
    user_language_shown { "en" }
    device_xid { "gaFCZkxoGZYW6" }
    telltale_list do
      [
        "eng-1362",
        "eng-1362-game3-py-0."
      ]
    end
    user_ip { "10.211.121.196" }
    country { "AU" }
    region { "New South Wales" }
    city { "Sydney" }
    isp { "Amazon.com" }
    connection_type { "Data Center" }
    is_tor { false }
    is_vpn { true }
    is_proxy { true }
    is_bot { true }
    risk_band { "High" }
    risk_category { "BOT-STD" }
    global_score { 100 }
    custom_score { 100 }
  end
end
