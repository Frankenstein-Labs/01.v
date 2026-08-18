import { nextTick } from 'vue';
import { GlPopover, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import RiskScoreByProject from 'ee/security_dashboard/components/shared/charts/risk_score_by_project.vue';
import { generateGrid } from 'ee/security_dashboard/utils/chart_utils';

jest.mock('ee/security_dashboard/utils/chart_utils');

describe('RiskScoreByProject chart', () => {
  let wrapper;

  const DEFAULT_RISK_SCORES = [
    {
      project: {
        id: 1,
        name: 'Project Delta',
        fullPath: 'project/delta',
      },
      score: 85,
      rating: 'CRITICAL',
    },
    {
      project: {
        id: 2,
        name: 'Project Gamma',
        fullPath: 'project/gamma',
      },
      score: 65,
      rating: 'HIGH',
    },
    {
      project: {
        id: 3,
        name: 'Project Beta',
        fullPath: 'project/beta',
      },
      score: 35,
      rating: 'MEDIUM',
    },
    {
      project: {
        id: 4,
        name: 'Project Alpha',
        fullPath: 'project/alpha',
      },
      score: 15,
      rating: 'LOW',
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RiskScoreByProject, {
      propsData: {
        riskScores: DEFAULT_RISK_SCORES,
        ...props,
      },
      directives: {
        GlResizeObserver: createMockDirective('gl-resize-observer'),
      },
      stubs: {
        GlPopover: stubComponent(GlPopover, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      },
    });
  };

  const findRiskScoreTiles = () => wrapper.findAllByTestId('risk-score-tile');
  const findRiskScoreTile = (index) => findRiskScoreTiles().at(index);
  const findPopovers = () => wrapper.findAllComponents(GlPopover);
  const findPopover = (index) => findPopovers().at(index);
  const findPopoverLink = (index) => findPopover(index).findComponent(GlLink);
  const findRiskScoreButtons = () => wrapper.findAllByRole('button');
  const findRiskScoreButton = (index) => findRiskScoreButtons().at(index);

  const triggerResizeObserver = (width = 600, height = 500) => {
    const resizeObserverEntry = {
      contentRect: { width, height },
    };
    getBinding(wrapper.element, 'gl-resize-observer').value(resizeObserverEntry);
    return nextTick();
  };
  const getGridStyle = (cols, rows) => {
    return `grid-template-columns: repeat(${cols}, 1fr); grid-template-rows: repeat(${rows}, 1fr);`;
  };

  beforeEach(async () => {
    generateGrid.mockReturnValue({ rows: 2, cols: 2 });
    createComponent();
    await triggerResizeObserver();
  });

  describe('grid rendering', () => {
    it('renders a grid container with resize observer', () => {
      expect(wrapper.classes()).toMatchObject(['gl-grid', 'gl-h-full', 'gl-gap-1']);
    });

    it('renders the correct number of risk score cells', () => {
      expect(findRiskScoreTiles()).toHaveLength(DEFAULT_RISK_SCORES.length);
    });

    it('applies the correct grid style based on dimensions', () => {
      expect(wrapper.attributes('style')).toBe(
        'grid-template-columns: repeat(2, 1fr); grid-template-rows: repeat(2, 1fr);',
      );
    });
  });

  describe('risk score cells', () => {
    it.each(DEFAULT_RISK_SCORES.map((item, index) => [item, index]))(
      'project risk score has expected tile properties',
      (riskScore, index) => {
        const text = findRiskScoreButton(index);
        expect(text.text()).toBe(`${riskScore.score}`);
        expect(text.attributes('aria-label')).toBe(
          `Project ${riskScore.project.name}, risk score: ${riskScore.score}`,
        );
        expect(findRiskScoreTile(index).classes()).toContain(
          `risk-score-bg-${riskScore.rating.toLowerCase()}`,
        );
        expect(findRiskScoreButton(index).classes()).toContain(
          `risk-score-tile-text-${riskScore.rating.toLowerCase()}`,
        );
      },
    );
  });

  describe('popovers', () => {
    it('renders a popover for each risk score', () => {
      expect(findPopovers()).toHaveLength(DEFAULT_RISK_SCORES.length);
    });

    const itemIndex = 0;

    it('has the correct target', () => {
      expect(findPopover(itemIndex).props('target')).toBe(
        `risk-score-by-project-${DEFAULT_RISK_SCORES[itemIndex].project.id}`,
      );
    });

    it('renders a link to the project vulnerability report', () => {
      expect(findPopoverLink(itemIndex).props('href')).toBe(
        `/${DEFAULT_RISK_SCORES[itemIndex].project.fullPath}/-/security/vulnerability_report`,
      );
    });

    it('renders the risk score', () => {
      expect(findPopover(itemIndex).text()).toContain(`${DEFAULT_RISK_SCORES[itemIndex].score}`);
    });

    it('renders correct risk rating', () => {
      expect(findPopover(itemIndex).text()).toContain('Critical risk score');
    });
  });

  describe('grid resizing', () => {
    it.each`
      givenWidth | givenHeight | expectedRows | expectedCols
      ${400}     | ${300}      | ${3}         | ${2}
      ${600}     | ${200}      | ${2}         | ${4}
      ${200}     | ${400}      | ${4}         | ${1}
    `(
      'given width "$givenWidth" and height "$givenHeight", updates grid to $expectedRows rows and $expectedCols columns',
      async ({ givenWidth, givenHeight, expectedRows, expectedCols }) => {
        generateGrid.mockReturnValue({ rows: expectedRows, cols: expectedCols });
        createComponent();
        await triggerResizeObserver(givenWidth, givenHeight);

        expect(wrapper.attributes('style')).toBe(getGridStyle(expectedCols, expectedRows));
      },
    );

    it('does not update grid dimensions when width is 0', async () => {
      const expectedGridStyle = getGridStyle(2, 2);
      expect(wrapper.attributes('style')).toBe(expectedGridStyle);

      generateGrid.mockClear();

      await triggerResizeObserver(0, 300);

      // same as before, not updated
      expect(wrapper.attributes('style')).toBe(expectedGridStyle);
    });

    it('does not update grid dimensions when height is 0', async () => {
      const expectedGridStyle = getGridStyle(2, 2);
      expect(wrapper.attributes('style')).toBe(expectedGridStyle);

      generateGrid.mockClear();

      await triggerResizeObserver(300, 0);

      // same as before, not updated
      expect(wrapper.attributes('style')).toBe(expectedGridStyle);
    });
  });

  describe('with empty risk scores', () => {
    it('renders an empty grid', () => {
      generateGrid.mockReturnValue({ rows: 0, cols: 0 });
      createComponent({ riskScores: [] });

      expect(wrapper.exists()).toBe(true);
      expect(findRiskScoreTiles()).toHaveLength(0);
    });

    it('resets the grid dimensions', async () => {
      const expectedGridStyle = getGridStyle(0, 0);
      createComponent({ riskScores: [] });

      await triggerResizeObserver();

      expect(wrapper.attributes('style')).toBe(expectedGridStyle);
    });
  });
});
