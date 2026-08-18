import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import MRSecurityWidget from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SmartInterval from '~/smart_interval';
import api from '~/api';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  mockFindingReportsComparerSuccessResponse,
  mockFindingReportsComparerSuccessResponseWithFixed,
  mockFindingReportsComparerParsingResponse,
  createMockFindingReportsComparerResponse,
  createEnabledScansQueryResponse,
  createMockFinding,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/vue_shared/components/user_callout_dismisser.vue', () => ({
  render: () => {},
}));
jest.mock('~/smart_interval');

describe('MR Widget Security Reports', () => {
  let wrapper;
  let findingReportsComparerHandler;

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
  const reportsTabPath = '/-/merge_requests/1/reports';

  const defaultMrPropsData = {
    targetProjectFullPath: 'gitlab-org/gitlab',
    iid: 456,
    pipeline: {
      path: '/path/to/pipeline',
      id: 789,
      iid: 123,
    },
    enabledReports: {
      sast: true,
      dast: true,
      dependencyScanning: true,
      containerScanning: true,
      coverageFuzzing: true,
      apiFuzzing: true,
      secretDetection: true,
    },
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
    reportsTabPath,
  };

  const defaultMockApollo = createMockApollo([
    [
      enabledScansQuery,
      jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
    ],
    [
      findingReportsComparerQuery,
      jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse),
    ],
  ]);

  const createComponent = ({
    propsData,
    provide,
    mountFn = shallowMountExtended,
    mockApolloProvider,
    ...options
  } = {}) => {
    wrapper = mountFn(MRSecurityWidget, {
      apolloProvider: mockApolloProvider || createMockApollo(),
      provide: {
        glFeatures: { mrSecurityWidgetGraphql: true },
        ...provide,
      },
      propsData: {
        ...propsData,
        mr: {
          ...defaultMrPropsData,
          ...propsData?.mr,
        },
      },
      stubs: {
        VulnerabilityFindingModal: stubComponent(VulnerabilityFindingModal),
      },
      ...options,
    });
  };

  const createComponentWithMockData = (mockResponse) => {
    findingReportsComparerHandler = jest.fn().mockResolvedValue(mockResponse);

    createComponent({
      mountFn: mountExtended,
      apolloProvider: createMockApollo([
        [
          enabledScansQuery,
          jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        ],
        [findingReportsComparerQuery, findingReportsComparerHandler],
      ]),
    });

    return waitForPromises();
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);

  const getFirstScanResult = () => {
    const fetchFunctions = findWidget().props('fetchCollapsedData')();
    return fetchFunctions[0]();
  };

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
  });

  describe('with active pipeline', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: true } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with no enabled reports', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: false, enabledReports: {} } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with only clusterImageScanning enabled', () => {
    beforeEach(async () => {
      const onlyClusterImageScanningEnabled = {
        sast: false,
        dast: false,
        dependencyScanning: false,
        containerScanning: false,
        coverageFuzzing: false,
        apiFuzzing: false,
        secretDetection: false,
        clusterImageScanning: true,
      };
      createComponent({
        propsData: { mr: { isPipelineActive: false, enabledReports: {} } },
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: { ...onlyClusterImageScanningEnabled },
                partial: { ...onlyClusterImageScanningEnabled },
              }),
            ),
          ],
        ]),
      });
      await waitForPromises();
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with empty MR data', () => {
    beforeEach(async () => {
      createComponent({ mockApolloProvider: defaultMockApollo });
      await waitForPromises();
    });

    it('should mount the widget component', () => {
      expect(findWidget().props()).toMatchObject({
        statusIconName: 'success',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: expect.any(Function),
        multiPolling: true,
      });
    });

    it('handles loading state', async () => {
      expect(findSummaryText().props()).toMatchObject({ isLoading: true });
      findWidget().vm.$emit('is-loading', false);
      await nextTick();
      expect(findSummaryText().props()).toMatchObject({ isLoading: false });
    });

    it('does not display the summary highlights component', () => {
      expect(findSummaryHighlights().exists()).toBe(false);
    });

    it('should not be collapsible', () => {
      expect(findWidget().props('isCollapsible')).toBe(false);
    });
  });

  describe('with MR data', () => {
    it('should make a call only for enabled reports', async () => {
      const handler = jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        mountFn: mountExtended,
        propsData: {
          mr: {
            enabledReports: {
              sast: true,
              dast: true,
            },
          },
        },
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      await waitForPromises();

      expect(handler).toHaveBeenCalledTimes(2);
      expect(handler).toHaveBeenCalledWith({
        fullPath: defaultMrPropsData.targetProjectFullPath,
        iid: String(defaultMrPropsData.iid),
        reportType: 'SAST',
        scanMode: 'FULL',
      });
      expect(handler).toHaveBeenCalledWith({
        fullPath: defaultMrPropsData.targetProjectFullPath,
        iid: String(defaultMrPropsData.iid),
        reportType: 'DAST',
        scanMode: 'FULL',
      });
    });

    it('should display the "View report" button', async () => {
      createComponent({ mockApolloProvider: defaultMockApollo });

      await waitForPromises();

      const actionButtons = findWidget().props('actionButtons');
      expect(actionButtons).toHaveLength(1);
      expect(actionButtons[0]).toMatchObject({
        href: `${reportsTabPath}/security-scan`,
        text: 'View report',
      });
    });

    it('onClick navigates to the reports tab without page reload', async () => {
      createComponent({ mockApolloProvider: defaultMockApollo });

      await waitForPromises();

      const pushStateSpy = jest.spyOn(window.history, 'pushState');
      const dispatchEventSpy = jest.spyOn(window, 'dispatchEvent');

      const actionButtons = findWidget().props('actionButtons');
      const event = { preventDefault: jest.fn() };
      actionButtons[0].onClick(actionButtons[0], event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(pushStateSpy).toHaveBeenCalledWith(null, null, `${reportsTabPath}/security-scan`);
      expect(dispatchEventSpy).toHaveBeenCalledWith(expect.any(PopStateEvent));
    });

    describe('tracking', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      it('onClick tracks click_view_report_on_merge_request_widget', async () => {
        createComponent({ mockApolloProvider: defaultMockApollo });
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        const actionButtons = findWidget().props('actionButtons');
        const event = { preventDefault: jest.fn() };
        actionButtons[0].onClick(actionButtons[0], event);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_view_report_on_merge_request_widget',
          { label: 'security_scan' },
          undefined,
        );
      });
    });

    it('should not be collapsible', async () => {
      const handler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [createMockFinding()],
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: { sast: true },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      await waitForPromises();

      expect(findWidget().props('isCollapsible')).toBe(false);
    });

    it('should mount the widget component', async () => {
      const handler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [createMockFinding(), createMockFinding()],
          fixed: [createMockFinding(), createMockFinding()],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      await waitForPromises();

      expect(findWidget().props()).toMatchObject({
        statusIconName: 'warning',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: wrapper.vm.fetchCollapsedData,
        multiPolling: true,
      });
    });

    it('computes the total number of new potential vulnerabilities correctly', async () => {
      const sastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [
            createMockFinding({ severity: 'CRITICAL' }),
            createMockFinding({ severity: 'HIGH' }),
          ],
          fixed: [createMockFinding(), createMockFinding()],
        }),
      );

      const dastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('DAST', {
          added: [
            createMockFinding({ severity: 'LOW' }),
            createMockFinding({ severity: 'UNKNOWN' }),
          ],
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
          [
            findingReportsComparerQuery,
            jest.fn((variables) => {
              if (variables.reportType === 'SAST') return sastHandler(variables);
              if (variables.reportType === 'DAST') return dastHandler(variables);
              return Promise.resolve(mockFindingReportsComparerSuccessResponse);
            }),
          ],
        ]),
      });

      await waitForPromises();

      expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
      expect(findSummaryHighlights().props()).toMatchObject({
        highlights: { critical: 1, high: 1, other: 2 },
      });
    });
  });

  describe('successful response', () => {
    it.each`
      type       | mockResponse
      ${'added'} | ${mockFindingReportsComparerSuccessResponse}
      ${'fixed'} | ${mockFindingReportsComparerSuccessResponseWithFixed}
    `(
      'clones "$type" GraphQL findings to make them mutable for UI state changes',
      async ({ type, mockResponse }) => {
        await createComponentWithMockData(mockResponse);
        const result = await getFirstScanResult();

        const originalFinding =
          mockResponse.data.project.mergeRequest.findingReportsComparer.report[type][0];

        expect(result.data[type][0]).not.toBe(originalFinding);
        expect(result.data[type][0]).toEqual(originalFinding);
      },
    );
  });

  describe('error handling', () => {
    const createComponentWithError = async () => {
      const graphqlError = {
        graphQLErrors: [
          {
            extensions: { code: 'PARSING_ERROR' },
            message: 'Schema parsing failed',
          },
        ],
      };

      const customHandler = jest.fn().mockRejectedValue(graphqlError);

      createComponent({
        mountFn: mountExtended,
        apolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          ],
          [findingReportsComparerQuery, customHandler],
        ]),
      });
      await waitForPromises();
    };

    it('handles GraphQL errors', async () => {
      await createComponentWithError();

      const result = await getFirstScanResult();
      expect(result.status).toBe(500);
      expect(result.data.error).toBe(true);
    });

    it('displays parsing error message in DOM', async () => {
      await createComponentWithError();
      await getFirstScanResult(); // Trigger the error

      expect(
        wrapper
          .findByText('Parsing schema failed. Check the validity of your .gitlab-ci.yml content.')
          .exists(),
      ).toBe(true);
    });
  });

  describe('polling behaviour', () => {
    const expectProcessingResult = (result) => {
      expect(result.status).toBe(202);
      expect(result.headers).toEqual({ 'poll-interval': 3000 });
      return result;
    };

    const expectParsedResult = (result) => {
      expect(result.status).toBe(200);
      expect(result.headers).toEqual({});
      expect(result.data.status).toBe('PARSED');
      return result;
    };

    describe('when status is PARSED', () => {
      beforeEach(async () => {
        await createComponentWithMockData(mockFindingReportsComparerSuccessResponse);
      });

      it('returns parsed data without polling headers', async () => {
        const result = await getFirstScanResult();

        expectParsedResult(result);
        expect(result.headers['poll-interval']).toBeUndefined();
      });
    });

    describe('when status is PROCESSING', () => {
      beforeEach(async () => {
        await createComponentWithMockData(mockFindingReportsComparerParsingResponse);
      });

      it('returns polling headers with 3 second interval', async () => {
        const result = await getFirstScanResult();

        expectProcessingResult(result);
      });
    });

    describe('polling sequence', () => {
      it('makes multiple requests when polling until PARSED', async () => {
        const customFindingReportsHandler = jest.fn();
        customFindingReportsHandler
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse) // Component setup
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse) // 1st poll - PROCESSING
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse); // 2nd poll - PARSED

        createComponent({
          mountFn: mountExtended,
          apolloProvider: createMockApollo([
            [
              enabledScansQuery,
              jest
                .fn()
                .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
            ],
            [findingReportsComparerQuery, customFindingReportsHandler],
          ]),
        });

        await waitForPromises();

        // 1st poll - returns PROCESSING
        let result = await getFirstScanResult();
        expectProcessingResult(result);

        // 2nd poll - returns PARSED
        result = await getFirstScanResult();
        expectParsedResult(result);

        expect(customFindingReportsHandler).toHaveBeenCalledTimes(3);
      });
    });
  });

  describe('partial scans', () => {
    it('displays loading state until enabled scans are fetched', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          ],
        ]),
      });

      const loadingText = 'Security scanning is loading';
      expect(findWidget().text()).toBe(loadingText);

      await waitForPromises();
      expect(findWidget().text()).not.toBe(loadingText);
    });

    it.each`
      fullScans | partialScans | expectedScanModes
      ${false}  | ${false}     | ${[]}
      ${true}   | ${false}     | ${['FULL']}
      ${false}  | ${true}      | ${['PARTIAL']}
      ${true}   | ${true}      | ${['FULL', 'PARTIAL']}
    `(
      'should fetch full scans=$fullScans, partial scans=$partialScans',
      async ({ fullScans, partialScans, expectedScanModes }) => {
        const handler = jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse);

        createComponent({
          mountFn: mountExtended,
          propsData: {
            mr: {
              enabledReports: {
                sast: true,
              },
            },
          },
          mockApolloProvider: createMockApollo([
            [
              enabledScansQuery,
              jest.fn().mockResolvedValue(
                createEnabledScansQueryResponse({
                  full: { sast: fullScans },
                  partial: { sast: partialScans },
                }),
              ),
            ],
            [findingReportsComparerQuery, handler],
          ]),
        });

        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(expectedScanModes.length);

        expectedScanModes.forEach((scanMode) => {
          expect(handler).toHaveBeenCalledWith({
            fullPath: defaultMrPropsData.targetProjectFullPath,
            iid: String(defaultMrPropsData.iid),
            reportType: 'SAST',
            scanMode,
          });
        });
      },
    );

    it('should refetch the query if scan is not ready', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest
              .fn()
              .mockResolvedValueOnce(
                createEnabledScansQueryResponse({
                  full: { ready: false },
                  partial: { ready: false },
                }),
              )
              .mockResolvedValueOnce(
                createEnabledScansQueryResponse({
                  full: { ready: true },
                  partial: { ready: true },
                }),
              ),
          ],
          [
            findingReportsComparerQuery,
            jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse),
          ],
        ]),
      });

      await waitForPromises();

      expect(SmartInterval).toHaveBeenCalledWith(
        expect.objectContaining({
          callback: expect.any(Function),
          incrementByFactorOf: 1,
          startingInterval: 3000,
          immediateExecution: true,
        }),
      );

      // Widget should be loading
      expect(findWidget().text()).toBe('Security scanning is loading');

      const spy = jest.spyOn(wrapper.vm.$options.pollingInterval, 'destroy');

      wrapper.vm.$apollo.queries.enabledScans.refetch();

      await waitForPromises();

      expect(spy).toHaveBeenCalledTimes(1);
    });

    it('when the query fails', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockRejectedValue({
              data: {},
            }),
          ],
        ]),
      });

      await waitForPromises();

      expect(
        wrapper.findByText('Error while fetching enabled scans. Please try again later.').exists(),
      ).toBe(true);
    });

    it('when the pipeline is null, it should not render anything', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValueOnce({
              data: {
                project: {
                  id: 'gid://1',
                  pipeline: null,
                },
              },
            }),
          ],
        ]),
      });

      await waitForPromises();

      expect(wrapper.text()).toBe('');
    });
  });
});
