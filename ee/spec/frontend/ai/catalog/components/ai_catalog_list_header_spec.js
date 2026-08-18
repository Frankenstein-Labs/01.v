import { GlExperimentBadge, GlLink, GlIcon, GlPopover, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';
import LinkToDashboardModal from 'ee/analytics/analytics_dashboards/link_to_dashboards/link_to_dashboards_modal.vue';
import {
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
} from 'ee/analytics/analytics_dashboards/link_to_dashboards/tracking';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { DOCS_URL } from '~/constants';

jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: (x) => x,
}));

describe('AiCatalogListHeader', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findHeaderActions = () => wrapper.findByTestId('ai-catalog-list-header-actions');
  const findDashboardLink = () => wrapper.findByTestId('ai-impact-dashboard-link');
  const findDashboardIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findPopoverLink = () => findPopover().findComponent(GlLink);
  const findLinkToDashboardModal = () => wrapper.findComponent(LinkToDashboardModal);
  const findNavTabs = () => wrapper.findComponent(AiCatalogNavTabs);
  const findNavActions = () => wrapper.findComponent(AiCatalogNavActions);
  const findLegalDisclaimer = () => wrapper.findByTestId('legal-disclaimer');

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogListHeader, {
      propsData: {
        ...props,
      },
      provide: {
        isGlobalNamespace: true,
        canAdmin: false,
        aiImpactDashboardEnabled: true,
        ...provide,
      },
      directives: {
        GlModal: createMockDirective('gl-modal'),
      },
      stubs,
    });
  };

  describe('default rendering', () => {
    it('renders default title', () => {
      createComponent({ provide: { aiImpactDashboardEnabled: false } });
      expect(findPageHeading().text()).toContain('AI Catalog');
    });

    it('renders description"', () => {
      createComponent();
      expect(findPageHeading().text()).toContain('Explore your GitLab Duo and SDLC trends');
    });

    describe('experiment badge visibility based on isExperiment prop', () => {
      it('should display experiment badge when isExperiment is true', () => {
        createComponent({ props: { isExperiment: true } });

        expect(findExperimentBadge().exists()).toBe(true);
        expect(findExperimentBadge().props('type')).toBe('experiment');
      });

      it('should display no badge when isExperiment is false', () => {
        createComponent({ props: { isExperiment: false } });

        expect(findExperimentBadge().exists()).toBe(false);
      });
    });

    it('renders AiCatalogNavTabs component', () => {
      createComponent();
      expect(findNavTabs().exists()).toBe(true);
    });

    it('renders AiCatalogNavActions component', () => {
      createComponent();
      expect(findNavActions().exists()).toBe(true);
    });
  });

  describe('dashboard link', () => {
    const mockDashboardPath = '/duo_and_sdlc_trends';

    describe('when `aiImpactDashboardEnabled` is false', () => {
      beforeEach(() => {
        createComponent({ provide: { aiImpactDashboardEnabled: false } });
      });

      it('does not render dashboard link', () => {
        expect(findDashboardLink().exists()).toBe(false);
      });

      it('does not render modal', () => {
        expect(findLinkToDashboardModal().exists()).toBe(false);
      });
    });

    describe('when `aiImpactDashboardEnabled` is true', () => {
      describe('default', () => {
        beforeEach(() => {
          createComponent({ provide: { aiImpactDashboardEnabled: true }, stubs: { GlSprintf } });
        });

        it('renders information icon', () => {
          expect(findDashboardIcon().exists()).toBe(true);
          expect(findDashboardIcon().props('name')).toBe('information-o');
        });

        it('has correct tracking attributes', () => {
          expect(findDashboardLink().attributes('data-track-action')).toBe(
            TRACKING_ACTION_CLICK_DASHBOARD_LINK,
          );
          expect(findDashboardLink().attributes('data-track-label')).toBe(
            TRACKING_LABEL_AI_CATALOG_HEADER,
          );
        });

        it('renders the info popover', () => {
          const id = findDashboardIcon().attributes('id');
          expect(id).toMatch(/.+/);
          expect(findPopover().props('target')).toBe(id);
        });

        it('renders the popover content with link', () => {
          expect(findPopover().text()).toMatchInterpolatedText(
            'This key dashboard provides visibility into SDLC metrics in the context of AI adoption for projects and groups. Learn more',
          );
          expect(findPopoverLink().attributes('href')).toBe(
            `${DOCS_URL}/user/analytics/duo_and_sdlc_trends/`,
          );
        });
      });

      describe('without dashboard path', () => {
        beforeEach(() => {
          createComponent({
            provide: { aiImpactDashboardEnabled: true, aiImpactDashboardPath: null },
            stubs: { GlSprintf },
          });
        });

        it('renders link without href', () => {
          expect(findDashboardLink().text()).toBe('Explore your GitLab Duo and SDLC trends');
          expect(findDashboardLink().attributes('href')).toBeUndefined();
        });

        it('sets the modal directive correctly', () => {
          const linkModalDirective = getBinding(findDashboardLink().element, 'gl-modal');

          expect(linkModalDirective.value).toBe('link-to-dashboard-modal');
          expect(findDashboardLink().attributes('href')).toBeUndefined();
        });

        it('renders modal with correct dashboard name', () => {
          expect(findLinkToDashboardModal().exists()).toBe(true);
          expect(findLinkToDashboardModal().props('dashboardName')).toBe('duo_and_sdlc_trends');
        });
      });

      describe('with dashboard path', () => {
        beforeEach(() => {
          createComponent({
            provide: {
              aiImpactDashboardEnabled: true,
              aiImpactDashboardPath: mockDashboardPath,
            },
            stubs: { GlSprintf },
          });
        });

        it('renders link to dashboard with correct href', () => {
          expect(findDashboardLink().text()).toBe('Explore your GitLab Duo and SDLC trends');
          expect(findDashboardLink().attributes('href')).toBe('/duo_and_sdlc_trends');
        });

        it('does not render modal', () => {
          expect(findLinkToDashboardModal().exists()).toBe(false);
        });
      });
    });
  });

  describe('when isGlobalNamespace is false', () => {
    describe('template', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isGlobalNamespace: false,
          },
        });
      });

      it('does not render AiCatalogNavTabs component', () => {
        expect(findNavTabs().exists()).toBe(false);
      });

      it('renders AiCatalogNavActions component in actions slot', () => {
        expect(findNavActions().exists()).toBe(true);
      });
    });

    it('passes canAdmin prop to nav actions', () => {
      createComponent({
        provide: { isGlobalNamespace: false },
        props: { canAdmin: true },
      });

      expect(findNavActions().props('canAdmin')).toBe(true);
    });

    it('passes newButtonVariant prop to nav actions', () => {
      createComponent({
        provide: { isGlobalNamespace: false },
        props: { newButtonVariant: 'confirm' },
      });

      expect(findNavActions().props('newButtonVariant')).toBe('confirm');
    });

    it('renders slot content in nav actions', () => {
      wrapper = shallowMountExtended(AiCatalogListHeader, {
        propsData: {},
        provide: {
          isGlobalNamespace: false,
        },
        slots: {
          'nav-actions': '<div data-testid="custom-nav-content">Custom Content</div>',
        },
      });

      expect(wrapper.findByTestId('custom-nav-content').exists()).toBe(true);
    });
  });

  describe('when isGlobalNamespace is true', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          isGlobalNamespace: true,
        },
      });
    });

    it('renders AiCatalogNavTabs component', () => {
      expect(findNavTabs().exists()).toBe(true);
    });

    it('renders AiCatalogNavActions component with canAdmin true', () => {
      const navActions = findNavActions();
      expect(navActions.exists()).toBe(true);
      expect(navActions.props('canAdmin')).toBe(true);
    });

    it('does not render nav actions in page heading actions slot', () => {
      // When isGlobalNamespace is true, nav actions are rendered in a separate div, not in the page heading actions
      const pageHeading = findPageHeading();
      expect(pageHeading.exists()).toBe(true);
    });
  });

  describe('when heading prop is passed', () => {
    beforeEach(() => {
      createComponent({
        props: { heading: 'Custom title' },
        provide: { aiImpactDashboardEnabled: false },
      });
    });

    it('renders provided title', () => {
      expect(findPageHeading().text()).toContain('Custom title');
    });
  });

  describe('legal disclaimer', () => {
    it('is rendered when showLegalDisclaimer is true', () => {
      createComponent({ provide: { showLegalDisclaimer: true } });

      expect(findLegalDisclaimer().exists()).toBe(true);
      expect(findLegalDisclaimer().text()).toContain('This catalog contains third-party content');
    });

    it('is not rendered when showLegalDisclaimer is false', () => {
      createComponent({ provide: { showLegalDisclaimer: false } });

      expect(findLegalDisclaimer().exists()).toBe(false);
    });
  });

  describe('actions container spacing', () => {
    it.each`
      isGlobalNamespace | canAdmin | aiImpactDashboardEnabled
      ${true}           | ${true}  | ${true}
      ${false}          | ${true}  | ${false}
      ${false}          | ${false} | ${true}
    `(
      'does not apply gap spacing when isGlobalNamespace=$isGlobalNamespace, canAdmin=$canAdmin and aiImpactDashboardEnabled=$aiImpactDashboardEnabled',
      ({ isGlobalNamespace, canAdmin, aiImpactDashboardEnabled }) => {
        createComponent({
          provide: { isGlobalNamespace, aiImpactDashboardEnabled },
          props: { canAdmin },
        });

        expect(findHeaderActions().classes()).not.toContain('gl-gap-5');
      },
    );

    it('applies gap spacing when isGlobalNamespace=false, canAdmin=true and aiImpactDashboardEnabled=true', () => {
      createComponent({
        provide: { isGlobalNamespace: false, aiImpactDashboardEnabled: true },
        props: { canAdmin: true },
      });

      expect(findHeaderActions().classes()).toContain('gl-gap-5');
    });
  });
});
