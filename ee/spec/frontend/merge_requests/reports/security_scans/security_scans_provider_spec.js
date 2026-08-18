import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SmartInterval from '~/smart_interval';
import SecurityScansProvider from 'ee/merge_requests/reports/security_scans/security_scans_provider.vue';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  createEnabledScansQueryResponse,
  mockFindingReportsComparerSuccessResponse,
  mockFindingReportsComparerParsingResponse,
  mockFindingReportsComparerEmptyResponse,
  createMockFindingReportsComparerResponse,
} from 'ee_jest/vue_merge_request_widget/mock_data';

jest.mock('~/smart_interval');

Vue.use(VueApollo);

describe('SecurityScansProvider', () => {
  let wrapper;

  const DEFAULT_MR_PROPS = {
    id: 12345,
    targetProjectFullPath: 'gitlab-org/gitlab',
    sourceProjectFullPath: 'namespace/project',
    sourceBranch: 'feature-branch',
    iid: 456,
    pipeline: {
      iid: 123,
      path: '/root/project/-/pipelines/123',
    },
  };

  const InjectedChild = {
    inject: [
      'enabledScans',
      'findingReports',
      'totalNewFindings',
      'highlights',
      'topLevelErrorMessage',
      'hasEnabledScans',
      'hasAtLeastOneReportWithMaxNewVulnerabilities',
      'hasFindingReportErrors',
      'hasFindings',
      'isLoadingScans',
      'loadingMessage',
      'statusMessage',
      'statusIconName',
      'updateFindingState',
    ],
    template: `
      <div data-testid="child">
        <span data-testid="is-loading-scans">{{ isLoadingScans }}</span>
        <span data-testid="loading-message">{{ loadingMessage }}</span>
        <span data-testid="status-message">{{ statusMessage }}</span>
        <span data-testid="status-icon-name">{{ statusIconName }}</span>
        <span data-testid="total-new-findings">{{ totalNewFindings }}</span>
        <span data-testid="highlights">{{ JSON.stringify(highlights) }}</span>
        <span data-testid="has-enabled-scans">{{ hasEnabledScans }}</span>
        <span data-testid="top-level-error-message">{{ topLevelErrorMessage }}</span>
        <span data-testid="has-at-least-one-report-with-max">{{ hasAtLeastOneReportWithMaxNewVulnerabilities }}</span>
        <span data-testid="has-finding-report-errors">{{ hasFindingReportErrors }}</span>
        <span data-testid="has-findings">{{ hasFindings }}</span>
        <span data-testid="finding-reports-count">{{ findingReports.length }}</span>
      </div>
    `,
  };

  const createComponent = ({ mr = {}, enabledScansHandler, findingReportsHandler } = {}) => {
    const mockApollo = createMockApollo([
      [
        enabledScansQuery,
        enabledScansHandler || jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
      ],
      [
        findingReportsComparerQuery,
        findingReportsHandler ||
          jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse),
      ],
    ]);

    wrapper = mount(SecurityScansProvider, {
      apolloProvider: mockApollo,
      propsData: {
        mr: { ...DEFAULT_MR_PROPS, ...mr },
      },
      provide: {
        projectPath: 'gitlab-org/gitlab',
        iid: '456',
      },
      slots: {
        default: InjectedChild,
      },
    });
  };

  const findByTestId = (testId) => wrapper.find(`[data-testid="${testId}"]`);
  const getTextByTestId = (testId) => findByTestId(testId).text();
  const findLoadingMessage = () => getTextByTestId('loading-message');
  const findStatusMessage = () => getTextByTestId('status-message');
  const findStatusIconName = () => getTextByTestId('status-icon-name');

  describe('rendering', () => {
    it('renders slot content', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
      });

      await waitForPromises();

      expect(findByTestId('child').exists()).toBe(true);
    });
  });

  describe('provided values', () => {
    describe('loadingMessage', () => {
      it('is set when enabledScans query is loading', () => {
        createComponent({
          enabledScansHandler: jest.fn().mockReturnValue(new Promise(() => {})),
        });

        expect(findLoadingMessage()).not.toBe('');
      });

      it('is set while scans are not ready', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(
            createEnabledScansQueryResponse({
              full: { ready: false },
              partial: { ready: false },
            }),
          ),
        });

        await waitForPromises();

        expect(findLoadingMessage()).not.toBe('');
      });

      it('is empty after enabledScans query completes with no scans enabled', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        });

        await waitForPromises();

        expect(findLoadingMessage()).toBe('');
      });

      it('is set when scans enabled but reports not yet loaded', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest.fn().mockReturnValue(new Promise(() => {})),
        });

        await waitForPromises();

        expect(findLoadingMessage()).not.toBe('');
      });

      it('is empty after reports are loaded', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        expect(findLoadingMessage()).toBe('');
      });

      it('is set while some reports are still being fetched', async () => {
        let resolveSecondReport;
        const findingReportsHandler = jest
          .fn()
          .mockResolvedValueOnce(mockFindingReportsComparerEmptyResponse)
          .mockReturnValueOnce(
            new Promise((resolve) => {
              resolveSecondReport = resolve;
            }),
          );

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(
              createEnabledScansQueryResponse({ full: { sast: true, dast: true } }),
            ),
          findingReportsHandler,
        });

        await waitForPromises();

        expect(findLoadingMessage()).not.toBe('');

        resolveSecondReport(mockFindingReportsComparerSuccessResponse);
        await waitForPromises();

        expect(findLoadingMessage()).toBe('');
      });

      it('is empty when there is an error', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockRejectedValue(new Error('Network error')),
        });

        await waitForPromises();

        expect(findLoadingMessage()).toBe('');
      });
    });

    describe('statusMessage', () => {
      it('shows correct message when pipelineIid is missing', () => {
        createComponent({ mr: { pipeline: null } });

        expect(findStatusMessage()).toContain(
          'No security scan results. Either CI/CD is not configured or the pipeline is not yet complete.',
        );
      });

      it('shows correct message when topLevelErrorMessage is set', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockRejectedValue(new Error('Network error')),
        });

        await waitForPromises();

        expect(findStatusMessage()).toContain('Error while fetching enabled scans');
      });

      it('shows correct message when no scans are enabled', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        });

        await waitForPromises();

        expect(findStatusMessage()).toContain('No security scans enabled.');
      });

      it('is empty when scans are enabled and loaded', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        expect(findStatusMessage()).toBe('');
      });
    });

    describe('statusIconName', () => {
      it('returns error when topLevelErrorMessage is set', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockRejectedValue(new Error('Network error')),
        });

        await waitForPromises();

        expect(findStatusIconName()).toBe('error');
      });

      it('returns warning when no scans are enabled', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        });

        await waitForPromises();

        expect(findStatusIconName()).toBe('warning');
      });

      it('returns warning when there are new findings', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        expect(findStatusIconName()).toBe('warning');
      });

      it('returns success when no findings and no errors', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerEmptyResponse),
        });

        await waitForPromises();

        expect(findStatusIconName()).toBe('success');
      });
    });

    describe('totalNewFindings', () => {
      it('returns 0 when no findings', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerEmptyResponse),
        });

        await waitForPromises();

        expect(getTextByTestId('total-new-findings')).toBe('0');
      });

      it('returns count from reports', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        expect(getTextByTestId('total-new-findings')).toBe('1');
      });

      it('sums findings from multiple reports', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(
              createEnabledScansQueryResponse({ full: { sast: true, dast: true } }),
            ),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        expect(getTextByTestId('total-new-findings')).toBe('2');
      });
    });

    describe('highlights', () => {
      it('returns empty object when no findings', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerEmptyResponse),
        });

        await waitForPromises();

        expect(getTextByTestId('highlights')).toBe('{}');
      });

      it('returns severity counts when findings exist', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        const highlights = JSON.parse(getTextByTestId('highlights'));
        expect(highlights).toEqual({
          critical: 0,
          high: 1,
          other: 0,
        });
      });
    });

    describe('hasEnabledScans', () => {
      it('is false when no scans enabled', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        });

        await waitForPromises();

        expect(getTextByTestId('has-enabled-scans')).toBe('false');
      });

      it('is true when scans are enabled', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        });

        await waitForPromises();

        expect(getTextByTestId('has-enabled-scans')).toBe('true');
      });

      it('is false when only clusterImageScanning is enabled', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(
              createEnabledScansQueryResponse({ full: { clusterImageScanning: true } }),
            ),
        });

        await waitForPromises();

        expect(getTextByTestId('has-enabled-scans')).toBe('false');
      });
    });

    describe('hasAtLeastOneReportWithMaxNewVulnerabilities', () => {
      it('is false when reports have fewer than 25 findings', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
        });

        await waitForPromises();

        expect(getTextByTestId('has-at-least-one-report-with-max')).toBe('false');
      });

      it('is true when a report has 25 findings', async () => {
        const findings = Array(25)
          .fill(null)
          .map((_, i) => ({
            title: `Finding ${i}`,
            uuid: `uuid-${i}`,
            severity: 'HIGH',
            state: 'DETECTED',
            foundByPipelineIid: '4',
          }));

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(
              createMockFindingReportsComparerResponse('SAST', { added: findings, fixed: [] }),
            ),
        });

        await waitForPromises();

        expect(getTextByTestId('has-at-least-one-report-with-max')).toBe('true');
      });
    });
  });

  describe('enabledScans query', () => {
    it('fetches with correct variables', () => {
      const enabledScansHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ enabledScansHandler });

      expect(enabledScansHandler).toHaveBeenCalledWith({
        fullPath: DEFAULT_MR_PROPS.targetProjectFullPath,
        pipelineIid: DEFAULT_MR_PROPS.pipeline.iid,
      });
    });

    it('skips query when pipelineIid is missing', () => {
      const enabledScansHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ mr: { pipeline: null }, enabledScansHandler });

      expect(enabledScansHandler).not.toHaveBeenCalled();
    });

    it('skips query when targetProjectFullPath is missing', () => {
      const enabledScansHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ mr: { targetProjectFullPath: null }, enabledScansHandler });

      expect(enabledScansHandler).not.toHaveBeenCalled();
    });

    describe('polling', () => {
      it('starts polling when scans are not ready', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(
            createEnabledScansQueryResponse({
              full: { ready: false },
              partial: { ready: false },
            }),
          ),
        });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalledWith(
          expect.objectContaining({
            callback: expect.any(Function),
            startingInterval: 3000,
            incrementByFactorOf: 1,
            immediateExecution: true,
          }),
        );
      });

      it('does not start polling when scans are ready', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        });

        await waitForPromises();

        expect(SmartInterval).not.toHaveBeenCalled();
      });

      it('stops polling when scans become ready', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        const enabledScansHandler = jest
          .fn()
          .mockResolvedValueOnce(
            createEnabledScansQueryResponse({ full: { ready: false }, partial: { ready: false } }),
          )
          .mockResolvedValueOnce(createEnabledScansQueryResponse());

        createComponent({ enabledScansHandler });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalled();

        wrapper.vm.$apollo.queries.enabledScans.refetch();
        await waitForPromises();

        expect(destroy).toHaveBeenCalled();
      });
    });

    describe('error handling', () => {
      it('sets error message when query fails', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockRejectedValue(new Error('Network error')),
        });

        await waitForPromises();

        expect(getTextByTestId('top-level-error-message')).toContain(
          'Error while fetching enabled scans',
        );
      });
    });
  });

  describe('findingReportsComparer query', () => {
    beforeEach(() => {
      jest.spyOn(console, 'warn').mockImplementation(() => {});
    });

    it.each`
      fullScans | partialScans | expectedScanModes
      ${false}  | ${false}     | ${[]}
      ${true}   | ${false}     | ${['FULL']}
      ${false}  | ${true}      | ${['PARTIAL']}
      ${true}   | ${true}      | ${['FULL', 'PARTIAL']}
    `(
      'fetches $expectedScanModes when full=$fullScans, partial=$partialScans',
      async ({ fullScans, partialScans, expectedScanModes }) => {
        const findingReportsHandler = jest
          .fn()
          .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(
            createEnabledScansQueryResponse({
              full: { sast: fullScans },
              partial: { sast: partialScans },
            }),
          ),
          findingReportsHandler,
        });

        await waitForPromises();

        expect(findingReportsHandler).toHaveBeenCalledTimes(expectedScanModes.length);

        expectedScanModes.forEach((scanMode) => {
          expect(findingReportsHandler).toHaveBeenCalledWith({
            fullPath: DEFAULT_MR_PROPS.targetProjectFullPath,
            iid: String(DEFAULT_MR_PROPS.iid),
            reportType: 'SAST',
            scanMode,
          });
        });
      },
    );

    it('fetches reports for multiple scan types', async () => {
      const findingReportsHandler = jest
        .fn()
        .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true, dast: true } })),
        findingReportsHandler,
      });

      await waitForPromises();

      expect(findingReportsHandler).toHaveBeenCalledTimes(2);
    });

    it('does not fetch while enabledScans is still polling', async () => {
      const findingReportsHandler = jest
        .fn()
        .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        enabledScansHandler: jest.fn().mockResolvedValue(
          createEnabledScansQueryResponse({
            full: { ready: false, sast: true },
            partial: { ready: false },
          }),
        ),
        findingReportsHandler,
      });

      await waitForPromises();

      expect(SmartInterval).toHaveBeenCalled();
      expect(findingReportsHandler).not.toHaveBeenCalled();
    });

    describe('polling', () => {
      it('starts polling when report status is PARSING', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerParsingResponse),
        });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalledWith(
          expect.objectContaining({
            callback: expect.any(Function),
            startingInterval: 3000,
            maxInterval: 30000,
            incrementByFactorOf: 1.5,
            immediateExecution: false,
          }),
        );
      });

      it('stops polling when report status becomes PARSED', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        const findingReportsHandler = jest
          .fn()
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse)
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse);

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler,
        });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalled();

        const pollerCallback = SmartInterval.mock.calls[0][0].callback;
        await pollerCallback();
        await waitForPromises();

        expect(destroy).toHaveBeenCalled();
      });

      it('cleans up pollers on destroy', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerParsingResponse),
        });

        await waitForPromises();

        wrapper.destroy();

        expect(destroy).toHaveBeenCalled();
      });

      it('clears loadingMessage after all pollers complete', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        const findingReportsHandler = jest
          .fn()
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse)
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse)
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse)
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse);

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(
              createEnabledScansQueryResponse({ full: { sast: true, secretDetection: true } }),
            ),
          findingReportsHandler,
        });

        await waitForPromises();

        const callbacks = SmartInterval.mock.calls.map((call) => call[0].callback);

        await callbacks[0]();
        await waitForPromises();
        expect(findLoadingMessage()).not.toBe('');

        await callbacks[1]();
        await waitForPromises();
        expect(findLoadingMessage()).toBe('');
      });
    });

    describe('error handling', () => {
      it('sets error message when all reports fail', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest.fn().mockRejectedValue(new Error('Network error')),
        });

        await waitForPromises();

        expect(getTextByTestId('top-level-error-message')).toContain(
          'Security reports failed loading results',
        );
      });

      it('does not set error message when some reports fail but not all', async () => {
        const findingReportsHandler = jest
          .fn()
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse)
          .mockRejectedValueOnce(new Error('Network error'));

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(
              createEnabledScansQueryResponse({ full: { sast: true, dast: true } }),
            ),
          findingReportsHandler,
        });

        await waitForPromises();

        expect(getTextByTestId('top-level-error-message')).toBe('');
        expect(getTextByTestId('has-finding-report-errors')).toBe('true');
      });

      it('sets parsing error message when PARSING_ERROR is returned', async () => {
        const parsingError = new Error('Parsing failed');
        parsingError.graphQLErrors = [
          {
            extensions: { code: 'PARSING_ERROR' },
            message: 'Schema parsing failed',
          },
        ];

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest.fn().mockRejectedValue(parsingError),
        });

        await waitForPromises();

        expect(getTextByTestId('top-level-error-message')).toContain('Parsing schema failed');
      });
    });
  });
});
