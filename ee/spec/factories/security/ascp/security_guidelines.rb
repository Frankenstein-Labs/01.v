# frozen_string_literal: true

FactoryBot.define do
  factory :security_ascp_security_guideline, class: 'Security::Ascp::SecurityGuideline' do
    project
    scan { association(:security_ascp_scan, project: project) }
    security_context { association(:security_ascp_security_context, project: project, scan: scan) }
    name { 'Shell Command Execution Policy' }
    operation { 'subprocess execution via os.system() or subprocess.run()' }
    legitimate_use { 'Running pre-approved system maintenance scripts' }
    security_boundary { 'User input directly passed to shell commands' }
    business_context { 'Affects system integrity and data security' }
    severity_if_violated { :high }
  end
end
