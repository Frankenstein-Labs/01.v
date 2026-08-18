import { GlBadge, GlSprintf } from '@gitlab/ui';
import { RouterLinkStub } from '@vue/test-utils';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import ApplicationCard from 'ee/cd/components/application_card.vue';
import {
  STATUS_AWAITING_APPROVAL,
  STATUS_DEGRADED,
  STATUS_DEPLOYING,
  STATUS_HEALTHY,
} from 'ee/cd/constants';
import { makeApplication as makeSharedApplication } from './mock_data';

describe('ApplicationCard', () => {
  let wrapper;

  const makeApplication = (config = {}) =>
    makeSharedApplication({
      id: 'gid://gitlab/Cd::Application/1',
      name: 'My App',
      lastDeployedAt: '2024-01-15T10:00:00Z',
      status: STATUS_HEALTHY,
      services: { count: 2 },
      ...config,
    });

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findCardLink = () => wrapper.findComponentByTestId('application-card-link');
  const findHeading = () => wrapper.find('h2');
  const findProjectAvatar = () => wrapper.findComponent(ProjectAvatar);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ApplicationCard, {
      propsData: {
        application: {},
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
        GlSprintf,
        TimeAgo,
      },
    });
  };

  describe('default', () => {
    const application = makeApplication({
      id: 'gid://gitlab/Cd::Application/1',
      name: 'Alpha',
      lastDeployedAt: '2020-04-01T00:00:00Z',
    });

    beforeEach(() => {
      createComponent({ application });
    });

    it('renders project avatar', () => {
      expect(findProjectAvatar().props('projectName')).toBe('Alpha');
    });

    it('renders the application name', () => {
      expect(findHeading().text()).toBe('Alpha');
    });

    it('renders the formatted last-deployed time', () => {
      expect(wrapper.text()).toContain('3 months ago');
    });

    it('sets the correct route for each link', () => {
      expect(findCardLink().props('to')).toEqual({
        name: 'applications_show_route',
        params: { id: '1' },
      });
    });
  });

  describe('services text', () => {
    it('renders the singular form when there is one service', () => {
      createComponent({ application: makeApplication({ services: { count: 1 } }) });

      expect(wrapper.text()).toContain('1 service');
    });

    it('renders the plural form when there are multiple services', () => {
      createComponent({ application: makeApplication({ services: { count: 4 } }) });

      expect(wrapper.text()).toContain('4 services');
    });
  });

  describe('statuses', () => {
    describe('with deploying status', () => {
      beforeEach(() => {
        createComponent({ application: makeApplication({ status: STATUS_DEPLOYING }) });
      });

      it('renders the status badge', () => {
        expect(findBadge().text()).toBe('Deploying');
        expect(findBadge().props('variant')).toBe('info');
      });

      it('renders the status description', () => {
        expect(wrapper.text()).toContain('Deployment in progress');
      });
    });

    describe('with degraded status', () => {
      beforeEach(() => {
        createComponent({ application: makeApplication({ status: STATUS_DEGRADED }) });
      });

      it('renders the status badge', () => {
        expect(findBadge().text()).toBe('Degraded');
        expect(findBadge().props('variant')).toBe('warning');
      });

      it('renders the status description', () => {
        expect(wrapper.text()).toContain('Degradation detected');
      });
    });
    describe('with healthy status', () => {
      beforeEach(() => {
        createComponent({ application: makeApplication({ status: STATUS_HEALTHY }) });
      });

      it('renders the status badge', () => {
        expect(findBadge().text()).toBe('Healthy');
        expect(findBadge().props('variant')).toBe('success');
      });

      it('renders the status description', () => {
        expect(wrapper.text()).toContain('All systems healthy');
      });
    });

    describe('with pending status', () => {
      beforeEach(() => {
        createComponent({ application: makeApplication({ status: STATUS_AWAITING_APPROVAL }) });
      });

      it('renders the status badge', () => {
        expect(findBadge().text()).toBe('Approval needed');
        expect(findBadge().props('variant')).toBe('warning');
      });

      it('renders the status description', () => {
        expect(wrapper.text()).toContain('Waiting for your approval');
      });
    });
  });

  describe('with null lastDeployedAt', () => {
    beforeEach(() => {
      createComponent({ application: makeApplication({ lastDeployedAt: null }) });
    });

    it('does not render the last-deployed text when lastDeployedAt is null', () => {
      expect(wrapper.text()).not.toContain('Last deployed');
    });
  });
});
