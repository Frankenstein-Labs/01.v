import { nextTick } from 'vue';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { GlStackedColumnChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import VulnerabilitiesByIdentifierChart from 'ee/security_dashboard/components/shared/charts/vulnerabilities_by_identifier_chart.vue';
import * as ChartUtils from 'ee/security_dashboard/utils/chart_utils';
import {
  listenSystemColorSchemeChange,
  removeListenerSystemColorSchemeChange,
} from '~/lib/utils/css_utils';

const mockSeverityColors = {
  critical: '#000000',
  high: '#111111',
  medium: '#222222',
  low: '#333333',
  info: '#444444',
  unknown: '#555555',
};
jest.mock('~/lib/utils/css_utils');

describe('VulnerabilitiesByIdentifierChart', () => {
  let wrapper;

  const mockVulnerabilitiesByIdentifier = [
    {
      name: 'CWE-79',
      url: 'https://cwe.mitre.org/data/definitions/79.html',
      bySeverity: [
        { severity: 'CRITICAL', count: 12 },
        { severity: 'HIGH', count: 24 },
      ],
    },
    {
      name: 'CWE-89',
      url: 'https://cwe.mitre.org/data/definitions/89.html',
      bySeverity: [
        { severity: 'CRITICAL', count: 15 },
        { severity: 'HIGH', count: 10 },
      ],
    },
  ];

  const findStackedColumnChart = () => wrapper.findComponent(GlStackedColumnChart);

  const mockFilters = {
    reportType: ['SAST'],
  };

  const defaultProps = {
    vulnerabilitiesByIdentifier: mockVulnerabilitiesByIdentifier,
    filters: mockFilters,
  };

  const defaultProvide = {
    securityVulnerabilitiesPath: '/group/security/vulnerabilities',
  };

  const createChartStub = (params) =>
    stubComponent(GlStackedColumnChart, {
      data: () => ({ params }),
      template: `
        <div>
          <slot name="tooltip-title" :params="params"></slot>
          <slot name="tooltip-content" :params="params"></slot>
        </div>`,
    });

  beforeEach(() => {
    jest.spyOn(ChartUtils, 'getSeverityColors').mockImplementation(() => mockSeverityColors);
  });

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(VulnerabilitiesByIdentifierChart, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        GlSprintf,
        ...stubs,
      },
    });
  };

  it('passes bars to GlStackedColumnChart', () => {
    createComponent();
    const bars = ChartUtils.formatVulnerabilitiesBySeries(mockVulnerabilitiesByIdentifier, {
      groupBy: 'severity',
      isStacked: true,
    });
    expect(findStackedColumnChart().props('bars')).toEqual(bars);
  });

  it('passes labels to GlStackedColumnChart', () => {
    createComponent();
    expect(findStackedColumnChart().props('groupBy')).toEqual(['CWE-79', 'CWE-89']);
  });

  it('uses stacked presentation', () => {
    createComponent();
    expect(findStackedColumnChart().props('presentation')).toBe('stacked');
  });

  describe('customPalette', () => {
    it.each([
      ['Critical', 'CRITICAL', mockSeverityColors.critical],
      ['High', 'HIGH', mockSeverityColors.high],
      ['Medium', 'MEDIUM', mockSeverityColors.medium],
      ['Low', 'LOW', mockSeverityColors.low],
      ['Info', 'INFO', mockSeverityColors.info],
      ['Unknown', 'UNKNOWN', mockSeverityColors.unknown],
    ])('applies the correct color for "%s" series', async (seriesName, severity, expectedColor) => {
      const vulnerabilitiesByIdentifier = [
        { name: 'CWE-79', url: '', bySeverity: [{ severity, count: 5 }] },
      ];

      createComponent({ props: { vulnerabilitiesByIdentifier } });
      await nextTick();

      expect(findStackedColumnChart().props('customPalette')).toEqual([expectedColor]);
    });
  });

  describe('system color scheme change listener', () => {
    it('calls "listenSystemColorSchemeChange" when mounted', () => {
      createComponent();
      expect(listenSystemColorSchemeChange).toHaveBeenCalled();
    });

    it('calls "removeListenerSystemColorSchemeChange" when component is destroyed', () => {
      createComponent();
      wrapper.destroy();

      expect(removeListenerSystemColorSchemeChange).toHaveBeenCalled();
    });
  });

  describe('tooltip', () => {
    const mockTooltipParams = {
      value: 'CWE-79',
      seriesData: [
        { seriesName: 'Critical', value: 12 },
        { seriesName: 'High', value: 24 },
      ],
    };

    const createComponentWithStubbedTooltip = ({ props = {}, provide = {} } = {}) => {
      createComponent({
        props,
        provide,
        stubs: {
          GlStackedColumnChart: createChartStub(mockTooltipParams),
        },
      });
    };

    const findAllLinks = () => wrapper.findAllComponents(GlLink);
    const findTitleLink = () => findAllLinks().at(0);
    const findSeverityLabels = () => wrapper.findAllComponents(GlChartSeriesLabel);
    const findMitreLabel = () => wrapper.findByTestId('mitre-label');
    const findMitreLink = () => findAllLinks().at(findAllLinks().length - 1);

    it('enables click-to-pin-tooltip on the chart', () => {
      createComponent();

      expect(findStackedColumnChart().props('clickToPinTooltip')).toBe(true);
    });

    describe('tooltip title', () => {
      it('renders a link to the vulnerabilities report filtered by identifier', () => {
        createComponentWithStubbedTooltip();

        expect(findTitleLink().attributes('href')).toContain('?identifier=CWE-79&reportType=SAST');
      });

      it('displays the identifier name', () => {
        createComponentWithStubbedTooltip();

        expect(findTitleLink().text()).toBe('CWE-79');
      });
    });

    describe('tooltip content', () => {
      it('renders a series label for each severity', () => {
        createComponentWithStubbedTooltip();

        expect(findSeverityLabels()).toHaveLength(2);
        expect(findSeverityLabels().at(0).text()).toBe('Critical');
        expect(findSeverityLabels().at(1).text()).toBe('High');
      });

      it('applies the correct color to series labels', async () => {
        createComponentWithStubbedTooltip();
        await nextTick();

        expect(findSeverityLabels().at(0).props('color')).toBe(mockSeverityColors.critical);
        expect(findSeverityLabels().at(1).props('color')).toBe(mockSeverityColors.high);
      });

      it('renders links with counts filtered by identifier and severity', () => {
        createComponentWithStubbedTooltip();

        const criticalLink = findAllLinks().at(1);
        const highLink = findAllLinks().at(2);

        expect(criticalLink.text()).toBe('12');
        expect(criticalLink.attributes('href')).toContain(
          '?identifier=CWE-79&reportType=SAST&severity=CRITICAL',
        );

        expect(highLink.text()).toBe('24');
        expect(highLink.attributes('href')).toContain(
          '?identifier=CWE-79&reportType=SAST&severity=HIGH',
        );
      });

      it('includes filters in the constructed URL', () => {
        const customFilters = {
          reportType: ['DAST'],
        };
        createComponentWithStubbedTooltip({ props: { filters: customFilters } });

        const criticalLink = findAllLinks().at(1);

        expect(criticalLink.attributes('href')).toContain('reportType=DAST');
      });

      it('renders a non-clickable span when the count is 0', () => {
        const zeroCountParams = {
          value: 'CWE-79',
          seriesData: [
            { seriesName: 'Critical', value: 0 },
            { seriesName: 'High', value: 24 },
          ],
        };

        createComponent({
          stubs: {
            GlStackedColumnChart: createChartStub(zeroCountParams),
          },
        });

        const links = wrapper.findAllComponents(GlLink);
        const linkTexts = links.wrappers.map((link) => link.text());

        expect(linkTexts).not.toContain('0');
        expect(linkTexts).toContain('24');
        expect(wrapper.text()).toContain('0');
      });
    });

    describe('when no securityVulnerabilitiesPath is provided', () => {
      beforeEach(() => {
        createComponentWithStubbedTooltip({ provide: { securityVulnerabilitiesPath: null } });
      });

      it('renders the identifier title as plain text, not a link', () => {
        const linkTexts = findAllLinks().wrappers.map((link) => link.text());

        expect(linkTexts).not.toContain('CWE-79');
        expect(wrapper.text()).toContain('CWE-79');
      });

      it('renders the severity counts as plain text, not links', () => {
        const linkTexts = findAllLinks().wrappers.map((link) => link.text());

        expect(linkTexts).not.toContain('12');
        expect(linkTexts).not.toContain('24');
        expect(wrapper.text()).toContain('12');
        expect(wrapper.text()).toContain('24');
      });

      it('still renders the MITRE definition link', () => {
        expect(findMitreLink().attributes('href')).toBe(
          'https://cwe.mitre.org/data/definitions/79.html',
        );
      });
    });

    describe('MITRE definition link', () => {
      it('renders the MITRE definition message', () => {
        createComponentWithStubbedTooltip();

        expect(findMitreLabel().text()).toBe(
          'To learn more about this CWE, view the MITRE definition.',
        );
      });

      it('links to the correct MITRE URL', () => {
        createComponentWithStubbedTooltip();

        expect(findMitreLink().attributes('href')).toBe(
          'https://cwe.mitre.org/data/definitions/79.html',
        );
      });

      it('does not render the MITRE link when URL is not available', () => {
        const paramsWithUnknownIdentifier = {
          value: 'UNKNOWN-ID',
          seriesData: [{ seriesName: 'Critical', value: 5 }],
        };

        createComponent({
          stubs: {
            GlStackedColumnChart: createChartStub(paramsWithUnknownIdentifier),
          },
        });

        expect(findMitreLabel().exists()).toBe(false);
      });
    });
  });
});
