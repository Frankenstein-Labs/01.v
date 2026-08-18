import { shallowMount } from '@vue/test-utils';
import { GlTruncate, GlDashboardPanel, GlLink, GlSprintf } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import VulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/charts/vulnerabilities_for_severity_panel.vue';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';

describe('VulnerabilitiesForSeverityPanel', () => {
  let wrapper;

  const findDashboardPanel = () => wrapper.findComponent(GlDashboardPanel);
  const findSingleStat = () => wrapper.findComponent(GlSingleStat);
  const findLink = () => wrapper.findComponent(GlLink);
  const findMedianLabel = () => wrapper.findComponent(GlTruncate);
  const findErrorMessage = () => wrapper.find('p');

  const defaultProps = {
    severity: 'critical',
    count: 42,
    medianAge: 105.5,
    filters: {
      reportType: ['SAST'],
    },
    error: false,
    loading: false,
  };
  const securityVulnerabilitiesPath = '/group/security/vulnerabilities';

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMount(VulnerabilitiesForSeverityPanel, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        securityVulnerabilitiesPath,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('severities', () => {
    const severityLevelsTestCases = Object.entries(SEVERITY_LEVELS).map(
      ([severity, expectedTitle]) => ({ severity, expectedTitle }),
    );
    describe.each(severityLevelsTestCases)(
      'when severity is "$severity"',
      ({ severity, expectedTitle }) => {
        beforeEach(() => {
          createComponent({ props: { severity } });
        });

        it('shows the correct title', () => {
          expect(findDashboardPanel().props('title')).toBe(expectedTitle);
        });

        it('passes the correct icon', () => {
          expect(findDashboardPanel().props('titleIcon')).toBe(`severity-${severity}`);
        });

        it('passes the correct icon class color', () => {
          expect(findDashboardPanel().props('titleIconClass')).toBe(
            `gl-mr-3 severity-text-${severity}`,
          );
        });

        it('constructs the correct link to the vulnerability report', () => {
          expect(findLink().props('href')).toBe(
            `${securityVulnerabilitiesPath}?severity=${severity.toUpperCase()}&reportType=SAST`,
          );
        });

        it('shows the correct info popover', () => {
          expect(findDashboardPanel().text()).toContain(
            `Total number of open ${expectedTitle.toLowerCase()} vulnerabilities and their median amount of time open. Select the number to see the open vulnerabilities in the vulnerability report.`,
          );
        });
      },
    );
  });

  describe('when no securityVulnerabilitiesPath is provided', () => {
    beforeEach(() => {
      createComponent({ provide: { securityVulnerabilitiesPath: null } });
    });

    it('does not render a link to the vulnerability report', () => {
      expect(findLink().exists()).toBe(false);
    });

    it('still renders the count as a single stat', () => {
      expect(findSingleStat().props('value')).toBe(defaultProps.count);
    });
  });

  describe('rendering states', () => {
    describe('normal state', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders GlSingleStat with correct value', () => {
        expect(findSingleStat().props('value')).toBe(defaultProps.count);
      });

      it('renders GlSingleStat with delimiter enabled', () => {
        expect(findSingleStat().props('useDelimiters')).toBe(true);
      });

      it('does not render error message', () => {
        expect(findErrorMessage().exists()).toBe(false);
      });

      it('shows a badge with the median age - plural', () => {
        const roundAge = Math.round(defaultProps.medianAge);
        expect(findMedianLabel().props('text')).toBe(`Median: ${roundAge} days`);
      });

      it('shows a badge with the median age - singular', () => {
        createComponent({ props: { medianAge: 1.2 } });
        expect(findMedianLabel().props('text')).toBe(`Median: 1 day`);
      });
    });

    describe('loading state', () => {
      beforeEach(() => {
        createComponent({ props: { loading: true } });
      });

      it('passes loading prop to dashboard panel', () => {
        expect(findDashboardPanel().props('loading')).toBe(true);
      });
    });

    describe('error state', () => {
      beforeEach(() => {
        createComponent({ props: { error: true } });
      });

      it('does not render GlSingleStat', () => {
        expect(findSingleStat().exists()).toBe(false);
      });

      it('does not render badge', () => {
        expect(findMedianLabel().exists()).toBe(false);
      });

      it('renders error message', () => {
        expect(findErrorMessage().text()).toBe('Something went wrong. Please try again.');
      });

      it('shows alert state in dashboard panel', () => {
        expect(findDashboardPanel().attributes('show-alert-state')).toBe('true');
      });

      it('passes error icon, color class, and border styling', () => {
        expect(findDashboardPanel().props()).toMatchObject({
          titleIcon: 'error',
          titleIconClass: 'gl-text-danger',
          borderColorClass: 'gl-border-t-red-500',
        });
      });
    });

    describe('zero count state', () => {
      beforeEach(() => {
        createComponent({ props: { count: 0, medianAge: null } });
      });

      it('displays 0 in GlSingleStat', () => {
        expect(findSingleStat().props('value')).toBe(0);
      });

      it('does not show any special empty state', () => {
        expect(findSingleStat().exists()).toBe(true);
        expect(findErrorMessage().exists()).toBe(false);
      });

      it('does not show median age badge', () => {
        expect(findMedianLabel().exists()).toBe(false);
      });

      it('does not mention median age in popover', () => {
        expect(findDashboardPanel().text()).toContain(
          `Total number of open critical vulnerabilities. Select the number to see the open vulnerabilities in the vulnerability report.`,
        );
      });
    });
  });
});
