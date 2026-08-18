import { nextTick } from 'vue';
import { GlTabs, GlTab } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import setWindowLocation from 'helpers/set_window_location_helper';
import App from '~/ci/analytics/project_ci_cd_analytics/components/app.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

import PipelinesDashboard from '~/ci/analytics/project_ci_cd_analytics/components/pipelines_dashboard.vue';
import ProjectQualitySummaryApp from 'ee_component/project_quality_summary/app.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  updateHistory: jest.fn(),
}));
jest.mock('ee_component/project_quality_summary/app.vue', () => ({
  name: 'ProjectQualitySummaryAppStub',
  render: () => {},
}));

describe('ProjectsPipelinesChartsApp', () => {
  let wrapper;
  let trackEventSpy;

  const projectPath = 'funkys/flightjs';
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createWrapper = ({ provide, ...options } = {}) => {
    wrapper = shallowMount(App, {
      provide: {
        projectPath,
        ...provide,
      },
      ...options,
    });

    trackEventSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
  };

  const findGlTabs = () => wrapper.findComponent(GlTabs);
  const findAllGlTabs = () => wrapper.findAllComponents(GlTab);
  const findGlTabAt = (index) => findAllGlTabs().at(index);

  const findPipelinesDashboard = () => wrapper.findComponent(PipelinesDashboard);

  const findProjectQualitySummaryApp = () => wrapper.findComponent(ProjectQualitySummaryApp);

  afterEach(() => {
    trackEventSpy.mockClear();
  });

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it(`renders the chart`, () => {
      expect(findPipelinesDashboard().exists()).toBe(true);
    });
  });

  describe('when project quality is available', () => {
    beforeEach(() => {
      createWrapper({
        provide: {
          shouldRenderQualitySummary: true,
        },
      });
    });

    it('shows 2 tabs', () => {
      expect(findAllGlTabs()).toHaveLength(2);
    });

    it('records event when the pipelines tab is clicked', () => {
      findGlTabAt(0).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith('p_analytics_ci_cd_pipelines', {}, undefined);
    });

    it('does not record an event when the project quality tab is clicked', () => {
      findGlTabAt(1).vm.$emit('click');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it(`renders tab with a title "Project quality" at index 1`, () => {
      expect(findGlTabAt(1).attributes('title')).toBe('Project quality');
    });

    it('renders the project quality summary', () => {
      expect(findProjectQualitySummaryApp().exists()).toBe(true);
    });
  });

  describe('query params', () => {
    describe.each`
      param                | tab
      ${''}                | ${'0'}
      ${'fake'}            | ${'0'}
      ${'pipelines'}       | ${'0'}
      ${'project-quality'} | ${'1'}
    `('$chart', ({ param, tab }) => {
      it('shows tab #$tab for URL parameter "$chart"', () => {
        setWindowLocation(`/?chart=${param}`);
        createWrapper({
          provide: {
            shouldRenderQualitySummary: true,
          },
        });

        expect(findGlTabs().attributes('value')).toBe(tab);
      });

      it('should set the tab when the back button is clicked', async () => {
        let popstateHandler;

        window.addEventListener = jest.fn();
        window.addEventListener.mockImplementation((event, handler) => {
          if (event === 'popstate') {
            popstateHandler = handler;
          }
        });

        createWrapper({
          provide: {
            shouldRenderQualitySummary: true,
          },
        });

        expect(findGlTabs().attributes('value')).toBe('0');

        setWindowLocation(`/?chart=${param}`);
        popstateHandler();
        await nextTick();

        expect(findGlTabs().attributes('value')).toBe(tab);
      });
    });
  });
});
