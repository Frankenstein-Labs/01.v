export const MOCK_SCANNERS_WITH_CUSTOM_VENDOR = [
  {
    id: 558,
    vendor: 'SamScan',
    report_type: 'SAST',
    name: 'A Custom Scanner',
    external_id: 'my_custom_scanner',
  },
];

export const MOCK_SCANNERS = [
  {
    id: 545,
    vendor: 'GitLab',
    report_type: 'SAST',
    name: 'ESLint',
    external_id: 'eslint',
  },
  {
    id: 546,
    vendor: 'GitLab',
    report_type: 'SAST',
    name: 'Find Security Bugs',
    external_id: 'find_sec_bugs',
  },
  {
    id: 541,
    vendor: 'GitLab',
    report_type: 'DEPENDENCY_SCANNING',
    name: 'Gemnasium',
    external_id: 'gemnasium',
  },
  {
    id: 548,
    vendor: 'GitLab',
    report_type: 'API_FUZZING',
    name: 'GitLab API Fuzzing',
    external_id: 'gitlab-api-fuzzing',
  },
  {
    id: 557,
    vendor: 'GitLab',
    report_type: 'SECRET_DETECTION',
    name: 'GitLeaks',
    external_id: 'gitleaks',
  },
  {
    id: 547,
    vendor: 'GitLab',
    report_type: 'COVERAGE_FUZZING',
    name: 'libfuzzer',
    external_id: 'libfuzzer',
  },
  {
    id: 542,
    vendor: 'GitLab',
    report_type: 'CONTAINER_SCANNING',
    name: 'Trivy',
    external_id: 'trivy',
  },
  {
    id: 544,
    vendor: 'GitLab',
    report_type: 'DAST',
    name: 'OWASP Zed Attack Proxy (ZAP)',
    external_id: 'zaproxy',
  },
  ...MOCK_SCANNERS_WITH_CUSTOM_VENDOR,
];
