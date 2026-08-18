import { nextTick } from 'vue';
import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import api from '~/api';

jest.mock('~/vue_shared/components/user_callout_dismisser.vue', () => ({
  render: () => {},
}));
jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  historyPushState: jest.fn(),
}));

describe('MR Widget Security Reports - Finding', () => {
  let wrapper;

  const securityConfigurationPath = '/help/user/application_security/_index.md';
  const sourceProjectFullPath = 'namespace/project';
  const sourceBranch = 'feature-branch';

  const sastHelp = '/help/user/application_security/sast/_index';
  const dastHelp = '/help/user/application_security/dast/_index';
  const coverageFuzzingHelp = '/help/user/application_security/coverage-fuzzing/index';
  const secretDetectionHelp = '/help/user/application_security/secret-detection/index';
  const apiFuzzingHelp = '/help/user/application_security/api-fuzzing/index';
  const dependencyScanningHelp = '/help/user/application_security/api-fuzzing/index';
  const containerScanningHelp = '/help/user/application_security/container-scanning/index';

  const createComponent = ({ propsData, provide, mountFn = mountExtended, ...options } = {}) => {
    wrapper = mountFn(ReportDetails, {
      provide,
      propsData: {
        ...propsData,
        widgetName: 'WidgetSecurityReports',
        mr: {
          targetProjectFullPath: 'gitlab-org/gitlab',
          pipeline: {
            path: '/path/to/pipeline',
            iid: 123,
          },
          ...propsData?.mr,
          securityConfigurationPath,
          sourceBranch,
          sourceProjectFullPath,
          sastHelp,
          dastHelp,
          containerScanningHelp,
          dependencyScanningHelp,
          coverageFuzzingHelp,
          secretDetectionHelp,
          apiFuzzingHelp,
        },
      },
      ...options,
    });
  };

  const mockReport = ({ reportType = 'SAST', full, partial } = {}) => {
    const createReport = (key) => ({
      reportTypeDescription: key.reportTypeDescription || reportType.toUpperCase(),
      numberOfNewFindings: key.numberOfNewFindings,
      numberOfFixedFindings: (key.findings?.length || 0) - (key.numberOfNewFindings || 0),
      testId: `${reportType.toLowerCase()}-scan-report`,
      findings: key.findings || [],
      added: key.findings?.slice(0, key.numberOfNewFindings),
      fixed: key.findings?.slice(key.numberOfNewFindings),
      error: key.error,
    });

    return {
      reportType,
      full: full ? createReport(full) : undefined,
      partial: partial ? createReport(partial) : undefined,
    };
  };

  const mockReportData = ({ findings, numberOfNewFindings } = {}) => ({
    numberOfNewFindings: numberOfNewFindings ?? findings?.length ?? 4,
    findings: findings || [
      {
        uuid: '1',
        severity: 'CRITICAL',
        title: 'Password leak',
        state: 'DISMISSED',
      },
      { uuid: '2', severity: 'HIGH', title: 'XSS vulnerability', state: 'DETECTED' },
      { uuid: '14abc', severity: 'MEDIUM', title: 'SQL vulnerability', state: 'DETECTED' },
      { uuid: 'bc41e', severity: 'LOW', title: 'SQL vulnerability 2', state: 'DETECTED' },
    ],
  });

  const createComponentWithData = async ({ reportType, full, partial } = {}) => {
    createComponent({
      propsData: {
        report: mockReport({
          reportType,
          partial,
          full,
        }),
      },
    });

    await nextTick();
  };

  const findMrWidgetRow = () => wrapper.findComponent(MrWidgetRow);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findDismissedBadge = () => wrapper.findByTestId('dismissed-badge');
  const findAutoDismissPolicyBadge = () =>
    wrapper.findComponentByTestId('auto-dismiss-policy-badge');
  const findAutoDismissPolicyBadgePopover = (uuid) =>
    wrapper.findComponentByTestId(`auto-dismiss-policy-badge-popover-${uuid}`);
  const findDynamicScroller = () => wrapper.findComponentByTestId('dynamic-content-scroller');

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
  });

  it('should display the dismissed badge', async () => {
    createComponentWithData({ full: mockReportData() });

    // This is for the dynamic scroller
    await nextTick();

    // Needed for Vue 3 specs
    await nextTick();

    expect(findDismissedBadge().text()).toBe('Dismissed');
  });

  it('computes the total number of new potential vulnerabilities correctly', async () => {
    await createComponentWithData({ full: mockReportData() });

    expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
    expect(findSummaryHighlights().props()).toMatchObject({
      highlights: { critical: 1, high: 1, other: 2 },
    });
  });

  it('displays detailed data', async () => {
    await createComponentWithData({ full: mockReportData() });

    expect(wrapper.findByText(/XSS vulnerability/).exists()).toBe(true);
    expect(wrapper.findByText(/Password leak/).exists()).toBe(true);
    expect(wrapper.findByTestId('sast-scan-report').text()).toBe(
      'SAST detected 4 new potential vulnerabilities',
    );
  });

  it('displays vulnerability list rows with correct data', async () => {
    await createComponentWithData({
      full: mockReportData({
        numberOfNewFindings: 1,
        numberOfFixedFindings: 0,
        findings: [
          { uuid: '14abc', severity: 'CRITICAL', title: 'SQL vulnerability', state: 'DETECTED' },
        ],
      }),
    });

    const mrWidgetRows = wrapper.findAllComponents(MrWidgetRow);
    const MrWidgetRowLastLevel = mrWidgetRows.at(1);

    expect(MrWidgetRowLastLevel.text()).toMatchInterpolatedText('Critical: SQL vulnerability');
    expect(MrWidgetRowLastLevel.props()).toMatchObject({
      statusIconName: 'severityCritical',
      level: 3,
    });
  });

  it('contains new and fixed findings in the dynamic scroller', async () => {
    await createComponentWithData({ full: mockReportData({ numberOfNewFindings: 2 }) });

    expect(findDynamicScroller().props('items')).toEqual([
      // New findings
      {
        uuid: '1',
        severity: 'CRITICAL',
        title: 'Password leak',
        state: 'DISMISSED',
      },
      { uuid: '2', severity: 'HIGH', title: 'XSS vulnerability', state: 'DETECTED' },
      // Fixed findings
      { uuid: '14abc', severity: 'MEDIUM', title: 'SQL vulnerability', state: 'DETECTED' },
      { uuid: 'bc41e', severity: 'LOW', title: 'SQL vulnerability 2', state: 'DETECTED' },
    ]);

    expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
    expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
  });

  it('contains only fixed findings in the dynamic scroller', async () => {
    await createComponentWithData({
      full: mockReportData({
        numberOfNewFindings: 0,
        numberOfFixedFindings: 2,
        findings: [
          { uuid: '14abc', severity: 'HIGH', title: 'SQL vulnerability', state: 'DETECTED' },
          { uuid: 'bc41e', severity: 'HIGH', title: 'SQL vulnerability 2', state: 'DETECTED' },
        ],
      }),
    });

    expect(findDynamicScroller().props('items')).toEqual([
      { uuid: '14abc', severity: 'HIGH', title: 'SQL vulnerability', state: 'DETECTED' },
      { uuid: 'bc41e', severity: 'HIGH', title: 'SQL vulnerability 2', state: 'DETECTED' },
    ]);

    expect(wrapper.findByTestId('new-findings-title').exists()).toBe(false);
    expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
  });

  it('contains only added findings in the dynamic scroller', async () => {
    await createComponentWithData({
      full: {
        findings: [
          { uuid: '5', severity: 'LOW', title: 'SQL Injection', state: 'DETECTED' },
          { uuid: '3', severity: 'UNKNOWN', title: 'Weak password', state: 'DETECTED' },
        ],
        numberOfNewFindings: 2,
      },
    });

    expect(findDynamicScroller().props('items')).toEqual([
      { uuid: '5', severity: 'LOW', title: 'SQL Injection', state: 'DETECTED' },
      { uuid: '3', severity: 'UNKNOWN', title: 'Weak password', state: 'DETECTED' },
    ]);

    expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
    expect(wrapper.findByTestId('fixed-findings-title').exists()).toBe(false);
  });

  describe('dynamic scroller max height', () => {
    it('applies max-height by default', async () => {
      await createComponentWithData({ full: mockReportData() });

      expect(findDynamicScroller().attributes('style')).toContain('max-height: 170px');
    });

    it('does not apply max-height when isReportsPage is true', () => {
      createComponent({
        propsData: {
          isReportsPage: true,
          report: mockReport({ full: mockReportData() }),
        },
      });

      expect(findDynamicScroller().attributes('style')).toBeUndefined();
    });
  });

  describe('resolve with AI badge', () => {
    const findingUuid = '1';
    const findAiResolvableBadge = () => wrapper.findByTestId('ai-resolvable-badge');
    const findAiResolvableBadgePopover = () =>
      wrapper.findByTestId(`ai-resolvable-badge-popover-${findingUuid}`);

    describe.each`
      resolveVulnerabilityWithAi | aiResolutionEnabled
      ${false}                   | ${true}
      ${true}                    | ${false}
    `(
      'with "resolveVulnerabilityWithAi" ability set to "$resolveVulnerabilityWithAi" and the vulnerability has "aiResolutionEnabled" set to: "$aiResolutionEnabled"',
      ({ resolveVulnerabilityWithAi, aiResolutionEnabled }) => {
        beforeEach(() =>
          createComponent({
            propsData: {
              report: mockReport({
                full: mockReportData({
                  numberOfNewFindings: 1,
                  findings: [
                    {
                      uuid: findingUuid,
                      severity: 'CRITICAL',
                      title: 'Password leak',
                      state: 'DISMISSED',
                      aiResolutionEnabled,
                    },
                  ],
                }),
              }),
            },
            provide: {
              glAbilities: {
                resolveVulnerabilityWithAi,
              },
            },
          }),
        );

        it('should not show the AI-Badge', () => {
          expect(findAiResolvableBadge().exists()).toBe(false);
        });

        it('should not show the AI-Badge popover', () => {
          expect(findAiResolvableBadgePopover().exists()).toBe(false);
        });
      },
    );

    describe('with "resolveVulnerabilityWithAi" ability set to "true" and the vulnerability has "aiResolutionEnabled" set to: "true"', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            glAbilities: {
              resolveVulnerabilityWithAi: true,
            },
          },
          propsData: {
            report: mockReport({
              full: {
                numberOfNewFindings: 1,
                findings: [
                  {
                    uuid: findingUuid,
                    severity: 'CRITICAL',
                    title: 'Password leak',
                    state: 'DISMISSED',
                    aiResolutionEnabled: true,
                  },
                ],
              },
            }),
          },
        });

        // Wait for the dynamic scroller
        await nextTick();
      });

      it('should show the AI-Badge', () => {
        expect(findAiResolvableBadge().exists()).toBe(true);
      });

      it('should add the correct id-attribute to the AI-Badge', () => {
        expect(findAiResolvableBadge().attributes('id')).toBe(`ai-resolvable-badge-${findingUuid}`);
      });

      it('should show a popover for the AI-Badge', () => {
        expect(findAiResolvableBadgePopover().exists()).toBe(true);
      });

      it('should pass the correct props to the AI-Badge popover', () => {
        expect(
          wrapper.findComponentByTestId('ai-resolvable-badge-popover-1').props(),
        ).toMatchObject({
          target: `ai-resolvable-badge-${findingUuid}`,
          // the popover and target are within a dynamic scroller, so this needs to be set to make it work correctly
          boundary: 'viewport',
        });
      });
    });
  });

  describe('error states', () => {
    it('displays an error message for the individual level report', async () => {
      await createComponent({
        propsData: { report: mockReport({ full: { error: true } }) },
      });

      expect(wrapper.findByText('SAST: Loading resulted in an error').exists()).toBe(true);
    });
  });

  describe('help popovers', () => {
    it.each`
      reportType               | reportTitle                                      | helpPath
      ${'SAST'}                | ${'Static Application Security Testing (SAST)'}  | ${sastHelp}
      ${'DAST'}                | ${'Dynamic Application Security Testing (DAST)'} | ${dastHelp}
      ${'DEPENDENCY_SCANNING'} | ${'Dependency scanning'}                         | ${dependencyScanningHelp}
      ${'COVERAGE_FUZZING'}    | ${'Coverage fuzzing'}                            | ${coverageFuzzingHelp}
      ${'API_FUZZING'}         | ${'API fuzzing'}                                 | ${apiFuzzingHelp}
      ${'SECRET_DETECTION'}    | ${'Secret detection'}                            | ${secretDetectionHelp}
      ${'CONTAINER_SCANNING'}  | ${'Container scanning'}                          | ${containerScanningHelp}
    `(
      'shows the correct help popover for $reportType',
      async ({ reportType, reportTitle, helpPath }) => {
        await createComponentWithData({ reportType });

        expect(findMrWidgetRow().props('helpPopover')).toMatchObject({
          options: { title: reportTitle },
          content: { learnMorePath: helpPath },
        });
      },
    );
  });

  describe('modal data', () => {
    it('should emit modal-data event when vulnerability is clicked', async () => {
      await createComponentWithData({ full: mockReportData() });

      // Click on the vulnerability name
      wrapper.findByText('Password leak').trigger('click');

      expect(wrapper.emitted('modal-data')[0][0]).toEqual({
        title: 'Password leak',
        severity: 'CRITICAL',
        state: 'DISMISSED',
        uuid: '1',
      });
    });
  });

  describe('auto dismiss policy badge', () => {
    const findingUuid = '1';

    describe.each`
      matchesAutoDismissPolicy
      ${false}
      ${undefined}
      ${null}
    `(
      'when "matchesAutoDismissPolicy" is set to "$matchesAutoDismissPolicy"',
      ({ matchesAutoDismissPolicy }) => {
        beforeEach(async () => {
          createComponent({
            propsData: {
              report: mockReport({
                full: mockReportData({
                  numberOfNewFindings: 1,
                  findings: [
                    {
                      uuid: findingUuid,
                      severity: 'CRITICAL',
                      title: 'Password leak',
                      state: 'NEW',
                      matchesAutoDismissPolicy,
                    },
                  ],
                }),
              }),
            },
          });

          await nextTick();
        });

        it('should not show the auto-dismiss-policy badge', () => {
          expect(findAutoDismissPolicyBadge().exists()).toBe(false);
        });

        it('should not show the auto-dismiss-policy badge popover', () => {
          expect(findAutoDismissPolicyBadgePopover(findingUuid).exists()).toBe(false);
        });
      },
    );

    describe('when "matchesAutoDismissPolicy" is set to "true"', () => {
      beforeEach(async () => {
        createComponent({
          propsData: {
            report: mockReport({
              full: {
                numberOfNewFindings: 1,
                findings: [
                  {
                    uuid: findingUuid,
                    severity: 'CRITICAL',
                    title: 'Password leak',
                    state: 'NEW',
                    matchesAutoDismissPolicy: true,
                  },
                ],
              },
            }),
          },
        });

        await nextTick();
      });

      it('should show the auto-dismiss-policy badge', () => {
        expect(findAutoDismissPolicyBadge().exists()).toBe(true);
      });

      it('should add the correct id-attribute to the auto-dismiss-policy badge', () => {
        expect(findAutoDismissPolicyBadge().attributes('id')).toBe(
          `auto-dismiss-policy-badge-${findingUuid}`,
        );
      });

      it('should have the correct data-testid attribute', () => {
        expect(findAutoDismissPolicyBadge().attributes('data-testid')).toBe(
          'auto-dismiss-policy-badge',
        );
      });

      it('should have the correct variant', () => {
        expect(findAutoDismissPolicyBadge().props('variant')).toBe('info');
      });

      it('should show a popover for the auto-dismiss-policy badge', () => {
        expect(findAutoDismissPolicyBadgePopover(findingUuid).exists()).toBe(true);
      });

      it('should pass the correct props to the auto-dismiss-policy badge popover', () => {
        expect(findAutoDismissPolicyBadgePopover(findingUuid).props()).toMatchObject({
          target: `auto-dismiss-policy-badge-${findingUuid}`,
          boundary: 'viewport',
          placement: 'top',
        });
      });

      it('should display the correct popover text', () => {
        expect(findAutoDismissPolicyBadgePopover(findingUuid).text()).toContain(
          'Vulnerability was matched by a policy and will be auto-dismissed.',
        );
      });

      it('should have a learn more link in the popover', () => {
        const learnMoreLink = findAutoDismissPolicyBadgePopover(findingUuid).findComponent({
          name: 'GlLink',
        });

        expect(learnMoreLink.exists()).toBe(true);
        expect(learnMoreLink.text()).toBe('Learn more');
        expect(learnMoreLink.attributes('href')).toContain(
          'user/application_security/policies/vulnerability_management_policy',
        );
      });
    });

    describe('when multiple vulnerabilities have different auto-dismiss-policy values', () => {
      beforeEach(async () => {
        createComponent({
          propsData: {
            report: mockReport({
              full: {
                numberOfNewFindings: 3,
                findings: [
                  {
                    uuid: '1',
                    severity: 'CRITICAL',
                    title: 'Password leak',
                    state: 'NEW',
                    matchesAutoDismissPolicy: true,
                  },
                  {
                    uuid: '2',
                    severity: 'HIGH',
                    title: 'XSS vulnerability',
                    state: 'NEW',
                    matchesAutoDismissPolicy: false,
                  },
                  {
                    uuid: '3',
                    severity: 'MEDIUM',
                    title: 'SQL vulnerability',
                    state: 'NEW',
                    matchesAutoDismissPolicy: true,
                  },
                  {
                    uuid: '4',
                    severity: 'MEDIUM',
                    title: 'SQL vulnerability',
                    state: 'DISMISSED',
                    matchesAutoDismissPolicy: true,
                  },
                ],
              },
            }),
          },
        });

        await nextTick();
      });

      it('should show the badge only for not dismissed vulnerabilities with matchesAutoDismissPolicy set to true', () => {
        const badges = wrapper.findAllByTestId('auto-dismiss-policy-badge');

        expect(badges).toHaveLength(2);
        expect(badges.at(0).attributes('id')).toBe('auto-dismiss-policy-badge-1');
        expect(badges.at(1).attributes('id')).toBe('auto-dismiss-policy-badge-3');
      });

      it('should show popovers only for not dismisssed vulnerabilities with matchesAutoDismissPolicy set to true', () => {
        expect(findAutoDismissPolicyBadgePopover('1').exists()).toBe(true);
        expect(findAutoDismissPolicyBadgePopover('2').exists()).toBe(false);
        expect(findAutoDismissPolicyBadgePopover('3').exists()).toBe(true);
        expect(findAutoDismissPolicyBadgePopover('4').exists()).toBe(false);
      });
    });

    describe('when auto-dismiss-policy badge is shown alongside aiResolvableBadge', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            glAbilities: {
              resolveVulnerabilityWithAi: true,
            },
          },
          propsData: {
            report: mockReport({
              full: {
                numberOfNewFindings: 1,
                findings: [
                  {
                    uuid: findingUuid,
                    severity: 'CRITICAL',
                    title: 'Password leak',
                    state: 'NEW',
                    matchesAutoDismissPolicy: true,
                    aiResolutionEnabled: true,
                  },
                ],
              },
            }),
          },
        });

        await nextTick();
      });

      it('should display both badges', () => {
        const aiResolvableBadge = wrapper.findByTestId('ai-resolvable-badge');
        const autoDismissBadge = findAutoDismissPolicyBadge();

        expect(aiResolvableBadge.exists()).toBe(true);
        expect(autoDismissBadge.exists()).toBe(true);
      });
    });

    describe('when auto-dismiss-policy badge is shown in partial scan', () => {
      beforeEach(async () => {
        createComponent({
          propsData: {
            report: mockReport({
              partial: {
                numberOfNewFindings: 1,
                findings: [
                  {
                    uuid: findingUuid,
                    severity: 'HIGH',
                    title: 'SQL Injection',
                    state: 'NEW',
                    matchesAutoDismissPolicy: true,
                  },
                ],
              },
            }),
          },
        });

        await nextTick();
      });

      it('should show the auto-dismiss-policy badge in partial scan', () => {
        expect(findAutoDismissPolicyBadge().exists()).toBe(true);
      });

      it('should show the popover for the auto-dismiss-policy badge in partial scan', () => {
        expect(findAutoDismissPolicyBadgePopover(findingUuid).exists()).toBe(true);
      });
    });
  });

  describe('tab view', () => {
    it.each`
      report                                                   | diffBasedScan | fullScan | testCase
      ${{ full: mockReportData(), partial: mockReportData() }} | ${true}       | ${true}  | ${'has both reports'}
      ${{ partial: mockReportData() }}                         | ${true}       | ${true}  | ${'has partial only'}
      ${{ full: mockReportData() }}                            | ${false}      | ${false} | ${'has full only'}
    `(
      'should adjust visibility of the tabs when $testCase',
      async ({ report, fullScan, diffBasedScan }) => {
        await createComponentWithData(report);

        expect(wrapper.findByText('Diff-based').exists()).toBe(diffBasedScan);
        expect(wrapper.findByText('Full scan').exists()).toBe(fullScan);
      },
    );

    it.each`
      report                           | shouldExist
      ${{ partial: mockReportData() }} | ${true}
      ${{ full: mockReportData() }}    | ${false}
    `(
      'should show the correct banner for diff-based tab view: $shouldExist',
      async ({ shouldExist, report }) => {
        await createComponentWithData(report);

        expect(
          wrapper
            .findByText(/This project uses diff-based scanning for GitLab Advanced SAST/)
            .exists(),
        ).toBe(shouldExist);
      },
    );

    it('should display full scans not enabled message when it is not configured', async () => {
      await createComponentWithData({ partial: mockReportData() });

      expect(wrapper.findByText('Full scan is not enabled for this project.').exists()).toBe(false);

      wrapper.findByText('Full scan').trigger('click');

      await nextTick();

      expect(wrapper.findByText('Full scan is not enabled for this project.').exists()).toBe(true);
    });

    it('should display an empty message for full scans when report has no data', async () => {
      await createComponentWithData({
        partial: mockReportData(),
        full: mockReportData({ findings: [] }),
      });

      expect(wrapper.findByText('No new vulnerabilities were found.').exists()).toBe(false);

      wrapper.findByText('Full scan').trigger('click');

      await nextTick();

      expect(wrapper.findByText('No new vulnerabilities were found.').exists()).toBe(true);
    });

    it('should display an empty message for diff scans when report has no data', async () => {
      await createComponentWithData({
        partial: mockReportData({ findings: [] }),
        full: mockReportData(),
      });

      expect(wrapper.findByText('No new vulnerabilities were found.').exists()).toBe(true);

      wrapper.findByText('Full scan').trigger('click');

      await nextTick();

      expect(wrapper.findByText('No new vulnerabilities were found.').exists()).toBe(false);
    });
  });
});
