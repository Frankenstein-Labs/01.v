import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormTextarea, GlLink, GlButton, GlEmptyState, GlDashboardPanel } from '@gitlab/ui';
import DataExplorer from 'ee/explore/analytics_dashboards/components/data_explorer.vue';
import SimpleCopyButton from '~/vue_shared/components/simple_copy_button.vue';
import AnalyticsDashboardPanel from '~/analytics/shared/components/analytics_dashboard_panel.vue';

describe('Data Explorer', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(DataExplorer, {
      propsData: props,
    });
  };

  const getTextArea = () => wrapper.findComponent(GlFormTextarea);
  const getSubmitBtn = () => wrapper.findComponent(GlButton);
  const getEmptyStatePanel = () => wrapper.findComponent(GlDashboardPanel);
  const getEmptyState = () => wrapper.findComponent(GlEmptyState);
  const getAnalyticsPanel = () => wrapper.findComponent(AnalyticsDashboardPanel);

  const runQuery = async () => {
    getSubmitBtn().vm.$emit('click');
    await nextTick();
  };

  describe('when rendered', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the text area', () => {
      expect(getTextArea().exists()).toBe(true);
    });

    it('does not render the copy query button', () => {
      expect(wrapper.findComponent(SimpleCopyButton).exists()).toBe(false);
    });

    it('renders the GLQL docs link', () => {
      const link = wrapper.findComponent(GlLink);
      expect(link.text()).toBe('What is GLQL?');
      expect(link.attributes('href')).toBe('/help/user/glql/_index');
    });

    it('renders a disabled `Run query` button', () => {
      expect(getSubmitBtn().text()).toBe('Run query');
      expect(getSubmitBtn().attributes('disabled')).toBeDefined();
    });

    it('renders the empty state preview inside a dashboard panel', () => {
      expect(getEmptyStatePanel().exists()).toBe(true);
      expect(getEmptyState().props()).toMatchObject({
        title: 'Preview not available',
        description: 'Start by typing a GLQL query.',
        svgPath: expect.any(String),
      });
    });

    it('does not render the analytics dashboard panel', () => {
      expect(getAnalyticsPanel().exists()).toBe(false);
    });
  });

  describe('query textarea field', () => {
    it('binds the query prop to the textarea value', () => {
      createWrapper({ query: 'existing query' });

      expect(getTextArea().props('value')).toBe('existing query');
    });

    it('emits input with the new value when the textarea changes', () => {
      createWrapper();

      getTextArea().vm.$emit('input', 'a new query');

      expect(wrapper.emitted('input')).toEqual([['a new query']]);
    });
  });

  describe('with query input', () => {
    const query = 'zzzzz';

    beforeEach(() => {
      createWrapper({ query });
    });

    it('renders the copy query button', () => {
      expect(wrapper.findComponent(SimpleCopyButton).props()).toMatchObject({
        title: 'Copy query',
        text: query,
      });
    });

    it('renders a clickable `Run query` button', () => {
      const button = wrapper.findComponent(GlButton);
      expect(button.text()).toBe('Run query');
      expect(button.attributes('disabled')).toBeUndefined();
    });

    it('does not render the analytics dashboard panel until the query is run', () => {
      expect(getAnalyticsPanel().exists()).toBe(false);
      expect(getEmptyStatePanel().exists()).toBe(true);
    });

    it('does not emit the submit event before the query is run', () => {
      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    describe('when the query is submitted', () => {
      beforeEach(() => runQuery());

      it('renders the query in an analytics dashboard panel as a GLQL visualization', () => {
        expect(getAnalyticsPanel().props('visualization')).toEqual({
          type: 'Glql',
          options: {},
          data: {
            type: 'glql',
            query: {
              glql: query,
            },
          },
        });
      });

      it('passes the default "Untitled" title to the panel when the query has no title', () => {
        expect(getAnalyticsPanel().props('title')).toBe('Untitled');
      });

      it('replaces the empty state preview with the panel', () => {
        expect(getEmptyStatePanel().exists()).toBe(false);
      });

      it('emits the submit event with the submitted query', () => {
        expect(wrapper.emitted('submit')).toEqual([[query]]);
      });

      describe('when a different query is run', () => {
        const newQuery = 'a different query';

        beforeEach(async () => {
          await wrapper.setProps({ query: newQuery });
          return runQuery();
        });

        it('emits the submit event with the new query', () => {
          expect(wrapper.emitted('submit')).toEqual([[query], [newQuery]]);
        });

        it('updates the panel visualization to the new query', () => {
          expect(getAnalyticsPanel().props('visualization')).toEqual({
            type: 'Glql',
            options: {},
            data: {
              type: 'glql',
              query: {
                glql: newQuery,
              },
            },
          });
        });
      });

      describe('when the same query is run again', () => {
        beforeEach(() => runQuery());

        it('re-submits the query so the panel re-renders', () => {
          expect(wrapper.emitted('submit')).toEqual([[query], [query]]);
        });
      });
    });
  });

  describe('when the query defines a frontmatter title', () => {
    const query = ['---', 'title: Open issues', '---', 'type = Issue AND state = opened'].join(
      '\n',
    );

    beforeEach(() => {
      createWrapper({ query });
      return runQuery();
    });

    it('passes the frontmatter title to the panel', () => {
      expect(getAnalyticsPanel().props('title')).toBe('Open issues');
    });
  });
});
