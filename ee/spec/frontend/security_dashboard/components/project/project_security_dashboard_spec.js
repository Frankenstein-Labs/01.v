import { GlLoadingIcon, GlSprintf, GlLink } from '@gitlab/ui';
import { GlLineChart } from '@gitlab/ui/src/charts';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ProjectSecurityDashboard from 'ee/security_dashboard/components/project/project_security_dashboard.vue';
import projectsHistoryQuery from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_day_and_count.query.graphql';
import severitiesCountQuery from 'ee/security_dashboard/graphql/queries/vulnerability_severities_count.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button.vue';
import { PdfExportError } from 'ee/security_dashboard/helpers';
import { mockProjectSecurityChartsWithData, mockSeverityCountsWithData } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Project Security Dashboard component', () => {
  let wrapper;
  let severitiesCountQueryHandler;

  const projectFullPath = 'project/path';

  const findLineChart = () => wrapper.findComponent(GlLineChart);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findExportButton = () => wrapper.findComponent(PdfExportButton);

  const createApolloProvider = (...queries) => {
    return createMockApollo([...queries]);
  };

  const defaultProps = {
    projectFullPath,
  };

  const createWrapper = ({ historyQueryData, severitiesCountQueryData, props = {} } = {}) => {
    severitiesCountQueryHandler = jest.fn().mockResolvedValue(severitiesCountQueryData);

    wrapper = shallowMountExtended(ProjectSecurityDashboard, {
      apolloProvider: createApolloProvider(
        [projectsHistoryQuery, jest.fn().mockResolvedValue(historyQueryData)],
        [severitiesCountQuery, severitiesCountQueryHandler],
      ),
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
        PageHeading,
      },
    });
  };

  it('should display page header and subheader', () => {
    createWrapper();

    expect(wrapper.findByTestId('page-heading').text()).toBe('Security dashboard');
    expect(wrapper.findByTestId('page-heading-description').text()).toBe(
      'Historical view of open vulnerabilities in the default branch. Excludes vulnerabilities that were resolved or dismissed. Learn more.',
    );
    expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
      '/help/user/application_security/security_dashboard/_index#project-security-dashboard',
    );
  });

  it('should fetch the latest vulnerability count for "detected" and "confirmed" states', () => {
    createWrapper();

    expect(severitiesCountQueryHandler).toHaveBeenCalledWith(
      expect.objectContaining({ state: ['DETECTED', 'CONFIRMED'] }),
    );
  });

  describe('when query is loading', () => {
    it('should only show the loading icon', () => {
      createWrapper();

      expect(findLineChart().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when there is history data', () => {
    useFakeDate(2021, 3, 11);
    const todayIso = '2021-04-11';

    beforeEach(async () => {
      createWrapper({
        historyQueryData: mockProjectSecurityChartsWithData(),
        severitiesCountQueryData: mockSeverityCountsWithData(),
      });
      await waitForPromises();
    });

    it('should display the chart with data', () => {
      expect(findLineChart().props('data')).toMatchSnapshot();
    });

    it.each(['critical', 'high', 'medium', 'info', 'unknown'])(
      'should use the up-to-date vulnerability count for the latest date for "%s" severity findings',
      (severity) => {
        const series = findLineChart()
          .props('data')
          .find(({ key }) => key === severity);
        const trendingData =
          mockProjectSecurityChartsWithData().data.project.vulnerabilitiesCountByDay.nodes;

        const todaysTrendingSeverityCount = trendingData.find(({ date }) => date === todayIso)[
          severity
        ];
        const latestSeverityCount =
          mockSeverityCountsWithData().data.project.vulnerabilitySeveritiesCount[severity];

        const [lastSeriesDate, lastSeriesCount] = series.data.at(-1);

        expect(lastSeriesDate).toBe(todayIso);
        expect(lastSeriesCount).toBe(latestSeverityCount);
        expect(lastSeriesCount).not.toBe(todaysTrendingSeverityCount);
      },
    );

    it('should display the chart with responsive attribute', () => {
      expect(findLineChart().attributes('responsive')).toBeDefined();
    });

    it('should not display the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('sets the contains `toolbox.show` option', () => {
      const { toolbox } = findLineChart().props('option');
      expect(toolbox).toMatchObject({ show: true });
    });

    it('contains the timeline slider', () => {
      const { dataZoom } = findLineChart().props('option');
      expect(dataZoom[0]).toMatchObject({
        type: 'slider',
        startValue: '2021-03-12',
      });
    });
  });

  describe('export button', () => {
    it('should display the export button', () => {
      createWrapper();
      expect(findExportButton().exists()).toBe(true);
    });

    it('generates the report data with chart SVG and path', async () => {
      createWrapper();
      await waitForPromises();

      const mockSvg = '<svg>mock chart data</svg>';
      const mockChart = {
        getDataURL: jest.fn().mockReturnValue(mockSvg),
      };

      findLineChart().vm.$emit('created', mockChart);

      const getReportDataFn = findExportButton().props('getReportData');
      const result = getReportDataFn();

      expect(result).toEqual({
        full_path: projectFullPath,
        project_vulnerabilities_history: {
          svg: mockSvg,
        },
      });
    });

    describe('error handling', () => {
      it("throws PdfExportError when it's loading", () => {
        createWrapper();
        const getReportDataFn = findExportButton().props('getReportData');

        expect(() => {
          getReportDataFn();
        }).toThrow(
          new PdfExportError('Chart is still loading. Please try again after all data has loaded.'),
        );
      });

      it('throws PdfExportError when chart is not initialized', async () => {
        createWrapper({
          historyQueryData: mockProjectSecurityChartsWithData(),
          severitiesCountQueryData: mockSeverityCountsWithData(),
        });
        await waitForPromises();

        const getReportDataFn = findExportButton().props('getReportData');

        expect(() => {
          getReportDataFn();
        }).toThrow(
          new PdfExportError('Chart failed to initialize. Please refresh the page and try again.'),
        );
      });
    });
  });
});
