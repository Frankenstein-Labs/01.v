import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import getUserCalloutsQuery from '~/graphql_shared/queries/get_user_callouts.query.graphql';
import WelcomePage from '~/vue_shared/new_namespace/components/welcome.vue';
import NewNamespacePage from '~/vue_shared/new_namespace/new_namespace_page.vue';

Vue.use(VueApollo);

jest.mock('~/lib/logger');

describe('Experimental new project creation app', () => {
  let wrapper;

  const findActivePanelTemplate = () => wrapper.findByTestId('active-panel-template');
  const findWelcomePage = () => wrapper.findComponent(WelcomePage);

  const DEFAULT_PROPS = {
    title: 'Create something',
    initialBreadcrumbs: [{ text: 'Something', href: '#' }],
    panels: [
      {
        name: 'panel1',
        selector: '#some-selector1',
        title: 'panel title',
        details: 'details1',
        description: 'description1',
        detailProps: { parentGroupName: '' },
      },
    ],
    persistenceKey: 'DEMO-PERSISTENCE-KEY',
  };

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      mount(NewNamespacePage, {
        propsData: {
          ...DEFAULT_PROPS,
          ...props,
        },
        provide: {
          identityVerificationRequired: false,
          identityVerificationPath: '#',
        },
        apolloProvider: createMockApollo([[getUserCalloutsQuery, {}]]),
      }),
    );
  };

  beforeEach(() => {
    setHTMLFixture('<div id="js-vue-page-breadcrumbs-wrapper"></div>');
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('shows breadcrumbs', async () => {
    createComponent();
    await nextTick();

    expect(
      document.querySelector('#js-vue-page-breadcrumbs-wrapper [data-testid="breadcrumb-links"]'),
    ).toBeDefined();
  });

  describe('active panel', () => {
    beforeEach(() => {
      setHTMLFixture(
        '<div id="js-vue-page-breadcrumbs-wrapper"></div><div id="some-selector1"></div>',
      );
    });

    it('shows active panel', () => {
      createComponent({ jumpToLastPersistedPanel: true });

      const wrapperText = wrapper.text();

      expect(findActivePanelTemplate().exists()).toBe(true);
      expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].title);
      expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].details);

      expect(findWelcomePage().exists()).toBe(false);
    });
  });

  it('shows welcome page', () => {
    createComponent();

    const wrapperText = wrapper.text();

    expect(findWelcomePage().exists()).toBe(true);
    expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].title);
    expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].description);

    expect(findActivePanelTemplate().exists()).toBe(false);
  });
});
